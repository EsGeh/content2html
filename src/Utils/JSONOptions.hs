module Utils.JSONOptions where


import Data.Aeson.TH
import Data.Char

jsonOptions :: Options
jsonOptions = defaultOptions{
	fieldLabelModifier =
		stripPrefix,
	constructorTagModifier =
		map toLower,
		--stripPrefix
	sumEncoding =
		ObjectWithSingleField
	--allNullaryToStringTag = False
	--omitNothingFields = True
	--unwrapUnaryRecords = True
}

stripPrefix :: String -> String
stripPrefix x =
	if ('_' `elem` x)
	then
		(drop 1 . dropWhile (/='_')) x
	else x
