{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE LambdaCase #-}
module Types.WebDocument where

import Utils.JSONOptions
import Types.URI
import Utils.Yaml

import qualified Data.Text as T
import Data.Aeson.TH
import GHC.Generics
import Control.Monad.Identity


-- | hierarchical html-document-like structure
data PageWithNav
	= PageWithNav {
		pageWithNav_nav :: Nav,
		pageWithNav_page :: Section,
		pageWithNav_headerInfo :: HeaderInfo
	}
	deriving( Show, Read, Eq, Ord, Generic )

type Nav = [NavEntry]

data HeaderInfo
	= HeaderInfo {
		headerInfo_userCss :: Maybe URI
	}
	deriving( Show, Read, Eq, Ord, Generic )

data NavEntry
	= NavEntry Link
	| NavCategory Title [NavEntry]
	deriving( Show, Read, Eq, Ord, Generic )

data Link
	= Link {
		link_caption :: Title,
		link_dest :: URI
	}
	deriving( Show, Read, Eq, Ord, Generic )

-- |a section in the document
type Section = SectionGen SectionInfo
-- |a tree of sections in which the leafs can optionally be "variables" of type var
type SectionTemplate var = SectionGen (Either var SectionInfo)

-- |A node in a tree of sections, either primitive or complex...
-- The type parameter contains the information describing the leaf nodes
data SectionGen sectionInfo
	= SectionEntry sectionInfo -- ^ primitive (leaf)
	| SectionNode (SectionNodeInfo sectionInfo) -- ^ complex section (inner node)
	deriving( Show, Read, Eq, Ord, Generic )

-- |a complex section consisting of other sections (inner node in the doc tree)
type SectionNodeInfo sectionInfo = SectionInfoGen [SectionGen sectionInfo]
-- |a primitive section (leaf of the doc tree)
type SectionInfo = SectionInfoGen WebContent

-- information for a "primitive" section containing additional info of type 'content'
data SectionInfoGen content
	= SectionInfo {
		section_title :: Maybe Title,
		section_content :: content,
		section_style :: StyleInfo
	}
	deriving( Show, Read, Eq, Ord, Generic )

defSectionInfo :: content -> SectionInfoGen content
defSectionInfo content = SectionInfo Nothing content defStyleInfo

data StyleInfo
	= StyleInfo {
		style_class :: Maybe T.Text
	}
	deriving( Show, Read, Eq, Ord, Generic )

defStyleInfo :: StyleInfo
defStyleInfo = StyleInfo Nothing

instance Functor SectionGen where
	fmap f = \case
		SectionEntry x -> SectionEntry $ f x
		SectionNode l -> SectionNode $ sectionInfo_mapToContent (map $ fmap f) l

{-
instance Foldable SectionGen where
	foldMap toM = \case
		SectionEntry info -> toM info
		SectionNode info ->
-}

{-
instance FromJSON Section where
	parseJSON = withObject "section" $ \o ->
		(SectionEntry <$> parseJSON (Object o))
		<|>
		(SectionNode <$> parseJSON (Object o))

instance FromJSON (SectionNodeInfo SectionInfo) where
	parseJSON = withObject "container section info" $ \o ->
		do
			title <- o .: "title"
			content <- o .: "subsections"
			return $ SectionInfo title content
-}

instance FromJSON SectionInfo where
	parseJSON = withObject "section info" $ \o ->
		do
			title <- o .:? "title"
			content <- o .: "content"
			style <- (StyleInfo) <$> o .:? "style_class"
			return $ SectionInfo title content style

sectionInfo_mapToContentM ::
	Monad m =>
	(content -> m content') -> SectionInfoGen content -> m (SectionInfoGen content')
sectionInfo_mapToContentM f p@SectionInfo{..} =
	f section_content >>= \new ->
	return p{ section_content = new }

sectionInfo_mapToContent :: 
	(content -> content') -> SectionInfoGen content -> SectionInfoGen content'
sectionInfo_mapToContent f = runIdentity . sectionInfo_mapToContentM (return . f)

section :: content -> SectionGen (SectionInfoGen content)
section content =
	SectionEntry $ defSectionInfo content
sectionWithTitle :: T.Text -> content -> SectionGen (SectionInfoGen content)
sectionWithTitle title content =
	SectionEntry $ (defSectionInfo content){ section_title = Just title }

mainSection :: [SectionGen info] -> SectionGen info
mainSection content =
	SectionNode $ defSectionInfo content
mainSectionWithTitle :: T.Text -> [SectionGen info] -> SectionGen info
mainSectionWithTitle title content =
	SectionNode $ (defSectionInfo content){ section_title = Just title }

eitherSection ::
	(info -> b)
	-> (SectionNodeInfo info -> b)
	-> SectionGen info -> b
eitherSection l r = \case
	SectionEntry e -> l e
	SectionNode e -> r e

class HasTitle a where
	sectionTitle :: a -> Maybe Title

instance HasTitle (SectionInfoGen content) where
	sectionTitle = section_title

instance HasTitle (SectionGen (SectionInfoGen content)) where
	sectionTitle (SectionEntry e) = sectionTitle e
	sectionTitle (SectionNode e) = sectionTitle e

class HasStyle a where
	sectionStyle :: a -> StyleInfo

instance HasStyle (SectionInfoGen content) where
	sectionStyle = section_style

instance HasStyle (SectionGen (SectionInfoGen content)) where
	sectionStyle (SectionEntry e) = sectionStyle e
	sectionStyle (SectionNode e) = sectionStyle e

data WebContent
	= Text T.Text
	| Image URI
	| Audio URI
	| Download DownloadInfo
	deriving( Show, Read, Eq, Ord, Generic  )

data DownloadInfo
	= DownloadInfo {
		download_caption :: T.Text,
		download_uri :: URI
	}
	deriving( Show, Read, Eq, Ord, Generic  )

type Title = T.Text

instance FromJSON DownloadInfo where
	parseJSON (Object x) =
		DownloadInfo <$>
		x.: "caption" <*>
		x.: "uri"
	parseJSON _ = mempty

instance ToJSON DownloadInfo where
	toJSON DownloadInfo{..} = object $
		[ "caption" .= download_caption
		, "uri" .= download_uri
		]

-- $(deriveJSON jsonOptions ''Page)
-- $(deriveJSON jsonOptions ''Article)
-- $(deriveJSON jsonOptions ''Section)
$(deriveJSON jsonOptions ''WebContent)