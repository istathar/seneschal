{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}

module Main where

import Core.Data (lookupKeyValue)
import Core.Program (
    Config,
    None (..),
    Options (..),
    ParameterValue (..),
    Program,
    Version (..),
    configure,
    executeWith,
    fromPackage,
    getCommandLine,
    inputEntire,
    parameterValuesFrom,
    simpleConfig,
 )
import Core.System (stdin)
import Core.Text (Rope, breakLines, emptyRope, fromRope, intoRope, quote)
import Data.Functor ((<&>))
import qualified Data.Text as T (replace)
import Seneschal (parallel)
import Prelude (IO, Maybe (..), ($), (<$>), (<>))

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
            -- Sadly, when you run `lookupKeyValue "replace-str", this
            -- default value gets completely ignored. :(
            -- TODO: write a function that returns the default value
            --       when the caller does to specify a --replace-str/-I
            --       value
            (Value "{}")
            [quote|
       String to use as the find-and-replace target in the stdin input or prefix value.
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
    Empty -> emptyRope

-- This is really ugly, and I can't even imagine the runtime cost I'm taking on
-- this, but I was in a hurry and wanted to get something running.
replace :: Rope -> Rope -> Rope -> Rope
replace needle replacement haystack = do
    let needleBS = fromRope needle
        replacementBS = fromRope replacement
        haystackBS = fromRope haystack
     in intoRope $ T.replace needleBS replacementBS haystackBS

-- Man, this is getting real indent-of-doom-like, which makes me sad.
program :: Program None ()
program = do
    params <- getCommandLine
    stdinBytes <- inputEntire stdin
    let hasValue v = parameterToRope <$> lookupKeyValue v (parameterValuesFrom params)
        stdinLines = breakLines $ intoRope stdinBytes
     in parallel $
            stdinLines <&> \line ->
                case (hasValue "prefix", hasValue "replace-str") of
                    (Just prefix, Nothing) -> prefix <> " " <> line
                    (Just prefix, Just needle) -> replace needle line prefix
                    (_, _) -> line
