{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes       #-}
{-# LANGUAGE TemplateHaskell   #-}

module Main where

import           Core.Program (Config, None (..), Options (..),
                               ParameterValue (..), Program, Version (..),
                               configure, executeWith, fromPackage,
                               getCommandLine, inputEntire, simpleConfig)
import           Core.System  (stdin)
import           Core.Text    (Rope, breakLines, emptyRope, fromRope, intoRope,
                               quote)
import           Data.Functor ((<&>))
import qualified Data.Text    as T (replace)
import           Prelude      (IO, Maybe (..), ($), (<>), (==))
import           Seneschal    (hasValue, parallel)

version :: Version
version = $(fromPackage)

myConfig :: Config
myConfig =
    simpleConfig
        [ Option
            "prefix"
            (Just 'p')
            (Value "")
            [quote|
        Specify a command prefix to, well, prefix to the input fed in via stdin.
        |]
        , Option
            "replace-str"
            (Just 'I')
            (Value "{}")
            [quote|
       String to use as the find-and-replace target in the stdin input or prefix value.
       |]
        , Variable
            "SHELL"
            [quote|
            Seneschal uses the $SHELL environment variable to detect what shell
            to run your commands in. This can be overridden with --shell
            |]
        , Option
            "shell"
            (Just 'S')
            Empty
            [quote|
           Shell to execute your command (or commands) in. By default, seneschal
           executes in the shell you're running, or the shell that's calling
           Seneschal.
           |]
        ]

main :: IO ()
main = do
    context <-
        configure
            version
            None
            myConfig
    executeWith context program

parameterToRope :: ParameterValue -> Rope
parameterToRope param = case param of
    Value p -> intoRope p
    Empty   -> emptyRope

-- This is really ugly, and I can't even imagine the runtime cost I'm taking on
-- this, but I was in a hurry and wanted to get something running.
replace :: Rope -> Rope -> Rope -> Rope
replace needle replacement haystack = do
    let needleBS = fromRope needle
        replacementBS = fromRope replacement
        haystackBS = fromRope haystack
     in intoRope $ T.replace needleBS replacementBS haystackBS

program :: Program None ()
program = do
    params <- getCommandLine
    stdinBytes <- inputEntire stdin
    let stdinLines = breakLines $ intoRope stdinBytes
     in parallel $
            stdinLines <&> \line ->
                case (hasValue "prefix" params, hasValue "replace-str" params) of
                    -- It'd be nice if the "{}" value in this case statement
                    -- came from something more intelligent, like the actual
                    -- default value.
                    (Just prefix, Nothing) -> let replLine = replace "{}" line prefix in if replLine == line then prefix <> " " <> line else replLine
                    (Just prefix, Just needle) -> replace needle line prefix
                    (_, _) -> line
