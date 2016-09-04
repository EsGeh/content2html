{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE RecordWildCards #-}
module ProjDB.Types where

import CMS.JSONOptions
import qualified CMS.Types as CMS

import Data.Aeson.TH
import Data.Aeson
import GHC.Generics
import qualified Data.Text as T
import qualified Data.Map as M
import qualified Lens.Micro.Platform as Lns
import qualified Language.Haskell.TH.Syntax as TH
import Control.Applicative

data ProjDB =
	ProjDB {
		db_artists :: M.Map ArtistKey Artist,
		db_projects :: M.Map ProjectKey Project,
		db_persons :: M.Map PersonKey Person
	}

type ArtistKey = Name
type ProjectKey = Name
type PersonKey = Name

type Name = T.Text

allArtists, allProjects, allPersons :: ProjDB -> [Name]
allArtists = M.keys . db_artists
allProjects = M.keys . db_projects
allPersons = M.keys . db_persons

lookupArtist :: ArtistKey -> ProjDB -> Maybe Artist
lookupArtist key = M.lookup key . db_artists
lookupProject :: ProjectKey -> ProjDB -> Maybe Project
lookupProject key = M.lookup key . db_projects
lookupPerson :: PersonKey -> ProjDB -> Maybe Person
lookupPerson key = M.lookup key . db_persons

projectsFromArtist :: Name -> ProjDB -> [Project]
projectsFromArtist key db =
	M.elems $
	M.filter ((key `elem`) . project_artist) $
	db_projects db

data Entry
	= ArtistEntry Artist
	| ProjectEntry Project
	| PersonEntry Person
	deriving( Read, Show, Generic, Eq, Ord )

data Artist
	= Artist {
		artist_name :: Name, -- key
		artist_persons :: [PersonKey]
	}
	deriving( Read, Show, Generic, Eq, Ord )

data Project
	= Project {
		project_name :: Name, -- key
		project_artist :: [ArtistKey],
		project_data :: [ProjectData]
		--project_data :: [CMS.WebContent]
	}
	deriving( Read, Show, Generic, Eq, Ord )

data Person
	= Person {
		person_name :: T.Text,
		person_born :: Maybe Date,
		person_dead :: Maybe Date
	}
	deriving( Read, Show, Generic, Eq, Ord )

data ProjectData
	= Audio AudioInfo
	| Document DocumentInfo
	deriving( Read, Show, Generic, Eq, Ord )

type AudioInfo
	= FilePath
	-- = Either URI FilePath

type DocumentInfo = FilePath

--newtype URI = URI { fromURI :: T.Text }

data Date
	= Date
	deriving( Read, Show, Generic, Eq, Ord )


flip Lns.makeLensesWith ''ProjDB $
	Lns.lensRules
		Lns.& Lns.lensField Lns..~ (\_ _ field -> [ Lns.TopName $ TH.mkName $ TH.nameBase field ++ "_L"])

-- $(deriveJSON jsonOptions ''Entry)
-- $(deriveJSON jsonOptions ''Artist)
-- $(deriveJSON jsonOptions ''Project)
$(deriveJSON jsonOptions ''Person)
$(deriveJSON jsonOptions ''Date)
-- $(deriveJSON jsonOptions ''ProjectData)

instance FromJSON Entry where
	parseJSON (Object x) =
		ArtistEntry <$> (parseJSON =<< x .: "artist")
		<|>
		ProjectEntry <$> (parseJSON =<< x .: "project")
		<|>
		PersonEntry <$> (parseJSON =<< x .: "person")

instance ToJSON Entry where
	toJSON x =
		case x of
			ArtistEntry x -> object [ "artist" .= toJSON x ]
			ProjectEntry x -> object [ "project" .= toJSON x ]
			PersonEntry x -> object [ "person" .= toJSON x ]

instance FromJSON Artist where
	parseJSON (Object x) =
		Artist <$>
		x.: "name" <*>
		x.:? "persons" .!= []

instance ToJSON Artist where
	toJSON Artist{..} = object $
		[ "name" .= artist_name
		]
		++ listMaybeEmpty "persons" artist_persons

instance FromJSON ProjectData where
	parseJSON (Object x) =
		Audio <$> x.: "audio"
		<|>
		Document <$> x.: "document"

instance ToJSON ProjectData where
	toJSON x =
		case x of
			Audio x' -> object $ ["audio" .= x']
			Document x' -> object $ ["document" .= x']

instance FromJSON Project where
	parseJSON (Object x) =
		Project <$>
		x.: "name" <*>
		x.: "artist" <*>
		x.:? "data" .!= []

instance ToJSON Project where
	toJSON (Project {..}) = object $
		[ "name".= project_name
		, "artist" .= project_artist
		]
		++
		listMaybeEmpty "data" project_data

listMaybeEmpty fieldName value =
	case value of
		[] -> []
		_ -> [ fieldName .= value ]

projDBFromEntries :: [Entry] -> ProjDB
projDBFromEntries =
	($ projDBDef)
	.
	foldl (.) id
	.
	(map $
	\entry ->
		case entry of
			ArtistEntry x -> insertArtist x
			PersonEntry x -> insertPerson x
			ProjectEntry x -> insertProject x
	)

projDBToEntries :: ProjDB -> [Entry]
projDBToEntries db =
	(fmap ArtistEntry $ M.elems $ db_artists db)
	++
	(fmap ProjectEntry $ M.elems $ db_projects db)
	++
	(fmap PersonEntry $ M.elems $ db_persons db)

projDBDef = ProjDB M.empty M.empty M.empty

insertArtist :: Artist -> ProjDB -> ProjDB
insertArtist x =
	Lns.over db_artists_L $
		M.insert (artist_name x) x
insertPerson x =
	Lns.over db_persons_L $
		M.insert (person_name x) x
insertProject x =
	Lns.over db_projects_L $
		M.insert (project_name x) x

{-

type MusicList = [Entry]

data Entry
	= Entry {
		entry_artist :: T.Text,
		entry_title :: T.Text,
		entry_comment :: T.Text
	}
	deriving( Read, Show, Generic, Eq, Ord )

type Key = (T.Text, T.Text) -- Artist, Title

{-
instance FromJSON Entry
instance ToJSON Entry
-}

$(deriveJSON jsonOptions ''Entry)
-}
