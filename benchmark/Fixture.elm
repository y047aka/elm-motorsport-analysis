module Fixture exposing (preprocessed)

import Data.Wec.Preprocess as Preprocess_Wec
import Fixture.Json exposing (jsonDecoded)
import Motorsport.Car exposing (Car)


preprocessed : List Car
preprocessed =
    Preprocess_Wec.preprocess jsonDecoded
