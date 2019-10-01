{-# LANGUAGE ConstraintKinds, MonoLocalBinds, RankNTypes, TypeOperators, UndecidableInstances #-}
module Semantic.Api.Terms
  (
    termGraph
  , parseTermBuilder
  , TermOutputFormat(..)

  , doParse
  , ParseEffects
  , TermConstraints

  ) where


import           Analysis.ConstructorName (ConstructorName)
import           Control.Effect.Error
import           Control.Effect.Parse
import           Control.Effect.Reader
import           Control.Lens
import           Control.Monad
import           Control.Monad.IO.Class
import           Data.Blob
import           Data.ByteString.Builder
import           Data.Either
import           Data.Graph
import           Data.JSON.Fields
import           Data.Language
import           Data.Quieterm
import           Data.Term
import qualified Data.Text as T
import qualified Data.Vector as V
import           Parsing.Parser
import           Prologue
import           Rendering.Graph
import           Rendering.JSON hiding (JSON)
import qualified Rendering.JSON
import           Semantic.Api.Bridge
import           Semantic.Config
import           Semantic.Proto.SemanticPB hiding (Blob)
import           Semantic.Task
import           Serializing.Format hiding (JSON)
import qualified Serializing.Format as Format
import           Source.Loc

termGraph :: (Traversable t, Member Distribute sig, ParseEffects sig m) => t Blob -> m ParseTreeGraphResponse
termGraph blobs = ParseTreeGraphResponse . V.fromList . toList <$> distributeFor blobs go
  where
    go :: ParseEffects sig m => Blob -> m ParseTreeFileGraph
    go blob = doParse (pure . jsonGraphTerm blob) blob
      `catchError` \(SomeException e) ->
        pure (ParseTreeFileGraph path lang mempty mempty (V.fromList [ParseError (T.pack (show e))]))
      where
        path = T.pack $ blobPath blob
        lang = bridging # blobLanguage blob


data TermOutputFormat
  = TermJSONTree
  | TermJSONGraph
  | TermSExpression
  | TermDotGraph
  | TermShow
  | TermQuiet
  deriving (Eq, Show)

parseTermBuilder :: (Traversable t, Member Distribute sig, ParseEffects sig m, MonadIO m)
  => TermOutputFormat -> t Blob -> m Builder
parseTermBuilder TermJSONTree    = distributeFoldMap jsonTerm >=> serialize Format.JSON -- NB: Serialize happens at the top level for these two JSON formats to collect results of multiple blobs.
parseTermBuilder TermJSONGraph   = termGraph >=> serialize Format.JSON
parseTermBuilder TermSExpression = distributeFoldMap (doParse sexprTerm)
parseTermBuilder TermDotGraph    = distributeFoldMap (doParse dotGraphTerm)
parseTermBuilder TermShow        = distributeFoldMap (doParse showTerm)
parseTermBuilder TermQuiet       = distributeFoldMap quietTerm

jsonTerm :: ParseEffects sig m => Blob -> m (Rendering.JSON.JSON "trees" SomeJSON)
jsonTerm blob = doParse (pure . jsonTerm' blob) blob `catchError` jsonError blob

jsonError :: Applicative m => Blob -> SomeException -> m (Rendering.JSON.JSON "trees" SomeJSON)
jsonError blob (SomeException e) = pure $ renderJSONError blob (show e)

quietTerm :: (ParseEffects sig m, MonadIO m) => Blob -> m Builder
quietTerm blob = showTiming blob <$> time' ( doParse (fmap (const (Right ())) . showTerm) blob `catchError` timingError )
  where
    timingError (SomeException e) = pure (Left (show e))
    showTiming Blob{..} (res, duration) =
      let status = if isLeft res then "ERR" else "OK"
      in stringUtf8 (status <> "\t" <> show (blobLanguage blob) <> "\t" <> blobPath blob <> "\t" <> show duration <> " ms\n")


type ParseEffects sig m = (Member (Error SomeException) sig, Member (Reader PerLanguageModes) sig, Member Parse sig, Member (Reader Config) sig, Carrier sig m)

class ( DOTGraphTerm t
      , JSONGraphTerm t
      , JSONTerm t
      , SExprTerm t
      , ShowTerm t
      )
   => TermConstraints t

instance ( DOTGraphTerm t
         , JSONGraphTerm t
         , JSONTerm t
         , SExprTerm t
         , ShowTerm t
         )
      => TermConstraints t

class ShowTerm term where
  showTerm :: (Carrier sig m, Member (Reader Config) sig) => term Loc -> m Builder

instance (Functor syntax, Show1 syntax) => ShowTerm (Term syntax) where
  showTerm = serialize Show . quieterm


class SExprTerm term where
  sexprTerm :: (Carrier sig m, Member (Reader Config) sig) => term Loc -> m Builder

instance (ConstructorName syntax, Foldable syntax, Functor syntax) => SExprTerm (Term syntax) where
  sexprTerm = serialize (SExpression ByConstructorName)

class DOTGraphTerm term where
  dotGraphTerm :: (Carrier sig m, Member (Reader Config) sig) => term Loc -> m Builder

instance (ConstructorName syntax, Foldable syntax, Functor syntax) => DOTGraphTerm (Term syntax) where
  dotGraphTerm = serialize (DOT (termStyle "terms")) . renderTreeGraph

class JSONTerm term where
  jsonTerm' :: Blob -> term Loc -> (Rendering.JSON.JSON "trees" SomeJSON)

instance ToJSONFields1 syntax => JSONTerm (Term syntax) where
  jsonTerm' = renderJSONTerm

class JSONGraphTerm term where
  jsonGraphTerm :: Blob -> term Loc -> ParseTreeFileGraph

instance (Foldable syntax, Functor syntax, ConstructorName syntax) => JSONGraphTerm (Term syntax) where
  jsonGraphTerm blob t
    = let graph = renderTreeGraph t
          toEdge (Edge (a, b)) = TermEdge (vertexId a) (vertexId b)
      in ParseTreeFileGraph path lang (V.fromList (vertexList graph)) (V.fromList (fmap toEdge (edgeList graph))) mempty where
        path = T.pack $ blobPath blob
        lang = bridging # blobLanguage blob


doParse
  :: ( Carrier sig m
     , Member (Error SomeException) sig
     , Member Parse sig
     )
  => (forall term . TermConstraints term => term Loc -> m a)
  -> Blob
  -> m a
doParse with blob = case blobLanguage blob of
  Go         -> parse goParser         blob >>= with
  Haskell    -> parse haskellParser    blob >>= with
  JavaScript -> parse tsxParser        blob >>= with
  JSON       -> parse jsonParser       blob >>= with
  JSX        -> parse tsxParser        blob >>= with
  Markdown   -> parse markdownParser   blob >>= with
  Python     -> parse pythonParser     blob >>= with
  Ruby       -> parse rubyParser       blob >>= with
  TypeScript -> parse typescriptParser blob >>= with
  TSX        -> parse tsxParser        blob >>= with
  PHP        -> parse phpParser        blob >>= with
  _          -> noLanguageForBlob (blobPath blob)
