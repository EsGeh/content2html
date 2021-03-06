{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE LambdaCase #-}
module Types.WebDocument.ToHtml(
	module Types.WebDocument.ToHtml,
	Html
) where

import Types.WebDocument
import Types.WebDocument.AttributesConfig
import Types.URI

import Lucid
import qualified Data.Text as T
import Data.Monoid
import Data.Maybe


pageWithNavToHtml :: AttributesCfg -> PageWithNav -> Html ()
pageWithNavToHtml attributes PageWithNav{..} =
	htmlHeader pageWithNav_headerInfo (fromMaybe "untitled" $ sectionTitle pageWithNav_page) $ do
		nav_ (attributesToLucid $ attributes_menuSection attributes) $
			div_ [ class_ $ T.pack "container-fluid"] $
			navToHtml (attributes_menuClasses attributes) pageWithNav_nav
		div_ (attributesToLucid $ attributes_mainSection attributes) $
			sectionToHtml
				(attributes_sectionHeading attributes)
				(attributes_section attributes)
				(attributes_formAttributes attributes)
				pageWithNav_page

htmlHeader :: HeaderInfo -> Title -> Html () -> Html ()
htmlHeader HeaderInfo{..} title content =
	html_ $ do
		meta_ [charset_ "utf-8"]
		head_ $ do
			mconcat $ map `flip` headerInfo_userCss $ \userCss ->
				link_ [rel_ "stylesheet", href_ (T.pack $ fromURI userCss)]
			toHtmlRaw $ headerInfo_addText
			title_ $ toHtml title
		body_ $ content

navToHtml :: MenuAttributes -> Nav -> Html ()
navToHtml attributes_ =
	navToHtml' attributes_ (0 :: Int)
	where
		navToHtml' :: MenuAttributes -> Int -> Nav -> Html ()
		navToHtml' attributes depth nav =
			ul_ (attributesToLucid $ ulAttributes) $ mconcat $ map `flip` nav $ \case
				NavEntry link ->
					li_ (attributesToLucid $ entryAttributes) $
						linkToHtml linkAttributes link
				NavCategory title subEntries ->
					li_ (attributesToLucid categoryAttributes) $ do
						a_ (attributesToLucid categoryLinkAttributes) $
							(toHtml title) <> span_ [class_ "caret"] (return ())
						navToHtml' newMenuAttributes (depth+1) subEntries
			where
				ulAttributes = head $ menuAttributes_menu attributes
				entryAttributes = head $ menuAttributes_entryClasses attributes
				linkAttributes = head $ menuAttributes_link attributes
				categoryAttributes = head $ menuAttributes_categoryClasses attributes
				categoryLinkAttributes = head $ menuAttributes_categoryLink attributes
				newMenuAttributes = MenuAttributes {
					menuAttributes_menu =
						tailIfNotEmpty (menuAttributes_menu attributes),
					menuAttributes_entryClasses =
						tailIfNotEmpty $ menuAttributes_entryClasses attributes,
					menuAttributes_link =
						tailIfNotEmpty $ menuAttributes_link attributes,
					menuAttributes_categoryClasses =
						tailIfNotEmpty $ menuAttributes_categoryClasses attributes,
					menuAttributes_categoryLink =
						tailIfNotEmpty $ menuAttributes_categoryLink attributes
				}

linkToHtml :: Attributes -> Link -> Html ()
linkToHtml attributes Link{..} =
	a_ ([href_ . T.pack . fromURI $ link_dest] ++ attributesToLucid attributes) $
		toHtml $ T.unpack link_caption

sectionToHtml :: [Attributes] -> [Attributes] -> FormAttributes -> Section -> Html ()
sectionToHtml attributesHeading_ attributes_ formAttributes = sectionToHtml' attributesHeading_ attributes_ 0
	where
		sectionToHtml' :: [Attributes] -> [Attributes] -> Int -> Section -> Html ()
		sectionToHtml' attributesHeading attributes depth x =
			div_ sectionAttributes $
			renderSection attributesHeadingHead depth (sectionTitle x) $
			eitherSection
				(contentToHtml formAttributes . section_content)
				(mconcat . map (sectionToHtml' (tailIfNotEmpty attributesHeading) (tailIfNotEmpty attributes) $ depth+1) . section_content) $
			x
			where
				sectionAttributes :: [Attribute]
				sectionAttributes =
					attributesToLucid $
					(`attributes_join` (getAttributes x)) $
					attributesHead
				attributesHeadingHead = head $ attributesHeading
				attributesHead = head $ attributes

contentToHtml :: FormAttributes -> WebContent -> Html ()
contentToHtml formAttributes@FormAttributes{..} x =
	case x of
		Text text ->
			p_ $ toHtml text
		Image uri ->
			img_ [src_ $ T.pack . fromURI $ uri, alt_ "an image"]
		Audio uri ->
			p_ $
			audio_ [controls_ "hussa"] $ do
				source_ [src_ . T.pack . fromURI $ uri]
				toHtml $ T.pack "your browser seems not to support html5 audio playback"
		Download DownloadInfo{..} ->
			a_ [href_ . T.pack . fromURI $ download_uri, download_ "" ] $ toHtml $ T.unpack download_caption
		Form FormInfo{..} ->
			form_ ([action_ $ form_action, method_ $ T.pack $ show form_method] ++ (attributesToLucid formAttributes_form)) $
				mconcat $ map `flip` form_content $ formEntryToHtml formAttributes
		List listInfo -> renderList listInfo


renderList :: ListInfo -> Html ()
renderList ListInfo{..} =
	(if list_ordered then ol_ else ul_) (attributesToLucid list_attributes) $
	mconcat $ map `flip` list_content $ \ListEntryInfo{..} ->
		li_ (attributesToLucid listEntry_attributes) $
			either toHtml renderList listEntry_content

formEntryToHtml :: FormAttributes -> FormEntry -> Html ()
formEntryToHtml FormAttributes{..} FormEntry{..} =
	div_ (attributesToLucid formAttributes_inputFieldDiv) $
	label_ (attributesToLucid formAttributes_label) (toHtml formEntry_caption) <>
	case formEntry_type of
		TextAreaInput ->
			textarea_ ([name_ formEntry_name] ++ attributesToLucid formAttributes_textArea) $ toHtml formEntry_default
		_ ->
			input_ ([type_ $ formEntryTypeToText $ formEntry_type, name_ formEntry_name, value_ formEntry_default] ++ attributesToLucid formAttributes_input)

renderSection :: Attributes -> Int -> Maybe Title -> Html () -> Html ()
renderSection attributes _ mTitle content =
	do
	--section_ [] $ do
		maybe
			mempty
			(\title -> header_ (attributesToLucid attributes) $ h2_ $ toHtml title)
			mTitle
		content

tailIfNotEmpty :: [a] -> [a]
tailIfNotEmpty l =
	case l of
		(_:[]) -> l
		(_:xs) -> xs
		_ -> l
