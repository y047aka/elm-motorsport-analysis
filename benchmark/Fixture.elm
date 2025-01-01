module Fixture exposing (preprocessed)

import Data.Wec.Preprocess as Preprocess_Wec
import Fixture.Csv exposing (csvDecoded)
import Motorsport.Car exposing (Car)


preprocessed : List Car
preprocessed =
    Preprocess_Wec.preprocess csvDecoded
