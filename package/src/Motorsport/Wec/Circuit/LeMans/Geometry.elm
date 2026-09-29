module Motorsport.Wec.Circuit.LeMans.Geometry exposing (LapPoint, PitPoint, centreline, frame, pitLane)

{-| The Circuit de la Sarthe as OpenStreetMap surveys it (2026-09-28T16:16:02Z),
in WGS84 degrees, with how far round the lap each point stands. North is up and
`y` runs south in the drawing these degrees are projected into, which
`Motorsport.Wec.Circuit.LeMans.Layout` writes. Written by
`app/scripts/le-mans-geometry.mjs`; edit that rather than this.

Map data © OpenStreetMap contributors, under the Open Database License.

@docs LapPoint, PitPoint, centreline, frame, pitLane

-}

import Motorsport.Circuit.Geodesy as Geodesy exposing (Frame)


{-| A point of the lap: where it stands on the earth, and how far round the lap it
is.
-}
type alias LapPoint =
    { lat : Float
    , lon : Float
    , metres : Float
    }


{-| Where the pit lane stands on the earth.
-}
type alias PitPoint =
    { lat : Float
    , lon : Float
    }


{-| The drawing's metres measured on the earth: every point below is where
[`Geodesy.project`](Motorsport-Circuit-Geodesy#project) puts it in this frame.
-}
frame : Frame
frame =
    Geodesy.frame
        { origin = { lat = 47.9618722, lon = 0.2074582 }
        , parallel = 47.943644259125485
        }


{-| The racing lap from the finish line, clockwise, back to the finish line.
`metres` is how far round the lap a point is, stretched to the 13,625.7 m of
Al Kamel's circuit maps. A sample read back off the line is stretched with it,
which is the scale the timing feed counts lap distances in.
-}
centreline : List LapPoint
centreline =
    [ { lat = 47.9498718, lon = 0.2075404, metres = 0 }
    , { lat = 47.9526555, lon = 0.2076815, metres = 310 }
    , { lat = 47.9529642, lon = 0.2077164, metres = 344.5 }
    , { lat = 47.9532565, lon = 0.2077702, metres = 377.3 }
    , { lat = 47.9536546, lon = 0.2078759, metres = 422.3 }
    , { lat = 47.9541588, lon = 0.2080424, metres = 479.8 }
    , { lat = 47.9544572, lon = 0.2081687, metres = 514.3 }
    , { lat = 47.9547879, lon = 0.2083361, metres = 553.2 }
    , { lat = 47.9552277, lon = 0.2086052, metres = 606.1 }
    , { lat = 47.9554103, lon = 0.2087638, metres = 629.6 }
    , { lat = 47.9555891, lon = 0.208972, metres = 654.9 }
    , { lat = 47.9557278, lon = 0.209193, metres = 677.5 }
    , { lat = 47.955823, lon = 0.2093975, metres = 696.1 }
    , { lat = 47.95644, lon = 0.2109034, metres = 827.7 }
    , { lat = 47.9564982, lon = 0.2110013, metres = 837.5 }
    , { lat = 47.9565523, lon = 0.2110361, metres = 844.1 }
    , { lat = 47.9566241, lon = 0.2110436, metres = 852.2 }
    , { lat = 47.9570197, lon = 0.2109233, metres = 897.2 }
    , { lat = 47.9570972, lon = 0.210955, metres = 906.2 }
    , { lat = 47.9571655, lon = 0.2110294, metres = 915.7 }
    , { lat = 47.9578848, lon = 0.2127024, metres = 1063.9 }
    , { lat = 47.9580246, lon = 0.2129969, metres = 1090.8 }
    , { lat = 47.9582243, lon = 0.2132896, metres = 1122.1 }
    , { lat = 47.9587894, lon = 0.213892, metres = 1199.4 }
    , { lat = 47.9589504, lon = 0.2141415, metres = 1225.2 }
    , { lat = 47.9590377, lon = 0.2143303, metres = 1242.4 }
    , { lat = 47.9591918, lon = 0.2148272, metres = 1283.2 }
    , { lat = 47.9592624, lon = 0.2151685, metres = 1309.9 }
    , { lat = 47.9592837, lon = 0.2154316, metres = 1329.7 }
    , { lat = 47.9593293, lon = 0.2167824, metres = 1430.5 }
    , { lat = 47.9593691, lon = 0.2170071, metres = 1447.9 }
    , { lat = 47.9594456, lon = 0.2171897, metres = 1464 }
    , { lat = 47.9595962, lon = 0.2174099, metres = 1487.6 }
    , { lat = 47.9598154, lon = 0.2175704, metres = 1514.8 }
    , { lat = 47.9599165, lon = 0.2176093, metres = 1526.5 }
    , { lat = 47.9601926, lon = 0.2176213, metres = 1557.2 }
    , { lat = 47.9603618, lon = 0.2176604, metres = 1576.3 }
    , { lat = 47.960543, lon = 0.2177559, metres = 1597.7 }
    , { lat = 47.9606469, lon = 0.2178513, metres = 1611.3 }
    , { lat = 47.9607869, lon = 0.2180813, metres = 1634.5 }
    , { lat = 47.9611901, lon = 0.2188778, metres = 1709 }
    , { lat = 47.9612933, lon = 0.2191357, metres = 1731.4 }
    , { lat = 47.961426, lon = 0.2195449, metres = 1765.3 }
    , { lat = 47.9618552, lon = 0.2212401, metres = 1900.4 }
    , { lat = 47.9618719, lon = 0.2213732, metres = 1910.5 }
    , { lat = 47.9618594, lon = 0.2215553, metres = 1924.2 }
    , { lat = 47.9618231, lon = 0.2216998, metres = 1935.7 }
    , { lat = 47.9616537, lon = 0.2221559, metres = 1974.6 }
    , { lat = 47.9613556, lon = 0.2228593, metres = 2036.7 }
    , { lat = 47.9611101, lon = 0.2233842, metres = 2084.4 }
    , { lat = 47.9608221, lon = 0.2238705, metres = 2132.9 }
    , { lat = 47.9606134, lon = 0.2241863, metres = 2165.9 }
    , { lat = 47.9601884, lon = 0.2246919, metres = 2226.4 }
    , { lat = 47.957933, lon = 0.2268118, metres = 2523.1 }
    , { lat = 47.9574614, lon = 0.2271909, metres = 2582.7 }
    , { lat = 47.9569696, lon = 0.2275149, metres = 2642.6 }
    , { lat = 47.956667, lon = 0.2276793, metres = 2678.4 }
    , { lat = 47.954966, lon = 0.228501, metres = 2877.4 }
    , { lat = 47.9451051, lon = 0.2332311, metres = 4030.3 }
    , { lat = 47.9449504, lon = 0.2332533, metres = 4047.6 }
    , { lat = 47.9448592, lon = 0.2332296, metres = 4058 }
    , { lat = 47.9447599, lon = 0.233163, metres = 4070.1 }
    , { lat = 47.944609, lon = 0.2329849, metres = 4091.6 }
    , { lat = 47.944513, lon = 0.2329192, metres = 4103.4 }
    , { lat = 47.9443812, lon = 0.2328975, metres = 4118.2 }
    , { lat = 47.9442424, lon = 0.2329309, metres = 4133.9 }
    , { lat = 47.9441703, lon = 0.2329805, metres = 4142.7 }
    , { lat = 47.9441137, lon = 0.2330501, metres = 4150.9 }
    , { lat = 47.9437376, lon = 0.2336859, metres = 4214.2 }
    , { lat = 47.9436168, lon = 0.2338589, metres = 4232.8 }
    , { lat = 47.9434914, lon = 0.2339771, metres = 4249.3 }
    , { lat = 47.9432732, lon = 0.2341138, metres = 4275.7 }
    , { lat = 47.9284765, lon = 0.2412308, metres = 6006.1 }
    , { lat = 47.9284048, lon = 0.2413033, metres = 6015.8 }
    , { lat = 47.9283206, lon = 0.2414574, metres = 6030.6 }
    , { lat = 47.9282686, lon = 0.2415944, metres = 6042.4 }
    , { lat = 47.9281791, lon = 0.2419772, metres = 6072.6 }
    , { lat = 47.9281397, lon = 0.2420627, metres = 6080.4 }
    , { lat = 47.9280612, lon = 0.2421678, metres = 6092.2 }
    , { lat = 47.9279415, lon = 0.2422536, metres = 6107 }
    , { lat = 47.9278183, lon = 0.242272, metres = 6120.9 }
    , { lat = 47.9277013, lon = 0.2422451, metres = 6134.1 }
    , { lat = 47.9272022, lon = 0.2420446, metres = 6191.6 }
    , { lat = 47.9270271, lon = 0.2420217, metres = 6211.2 }
    , { lat = 47.9268482, lon = 0.2420318, metres = 6231.2 }
    , { lat = 47.9266899, lon = 0.2420913, metres = 6249.3 }
    , { lat = 47.9250738, lon = 0.2428669, metres = 6438.3 }
    , { lat = 47.9247898, lon = 0.2429688, metres = 6470.8 }
    , { lat = 47.9243407, lon = 0.243066, metres = 6521.3 }
    , { lat = 47.9187062, lon = 0.2435767, metres = 7149.7 }
    , { lat = 47.9149906, lon = 0.2438741, metres = 7563.8 }
    , { lat = 47.9147164, lon = 0.243851, metres = 7594.4 }
    , { lat = 47.9145039, lon = 0.2438013, metres = 7618.4 }
    , { lat = 47.9135188, lon = 0.2433932, metres = 7732.2 }
    , { lat = 47.9134781, lon = 0.2433512, metres = 7737.7 }
    , { lat = 47.9134385, lon = 0.2432468, metres = 7746.7 }
    , { lat = 47.9134279, lon = 0.2431367, metres = 7755.1 }
    , { lat = 47.9134402, lon = 0.2430499, metres = 7761.7 }
    , { lat = 47.9150431, lon = 0.2342976, metres = 8438.2 }
    , { lat = 47.9151477, lon = 0.2337964, metres = 8477.4 }
    , { lat = 47.9152739, lon = 0.2333271, metres = 8515.1 }
    , { lat = 47.9153931, lon = 0.2329628, metres = 8545.3 }
    , { lat = 47.9173683, lon = 0.2272134, metres = 9027.1 }
    , { lat = 47.9176175, lon = 0.2266258, metres = 9079 }
    , { lat = 47.919617, lon = 0.2225963, metres = 9452.9 }
    , { lat = 47.9205666, lon = 0.2208583, metres = 9620.1 }
    , { lat = 47.9207559, lon = 0.2205948, metres = 9649 }
    , { lat = 47.9209799, lon = 0.2204131, metres = 9677.4 }
    , { lat = 47.9221579, lon = 0.219852, metres = 9815.1 }
    , { lat = 47.9222672, lon = 0.2197409, metres = 9829.8 }
    , { lat = 47.9223409, lon = 0.219564, metres = 9845.5 }
    , { lat = 47.9223581, lon = 0.2193477, metres = 9861.8 }
    , { lat = 47.9223246, lon = 0.2191249, metres = 9878.9 }
    , { lat = 47.9214544, lon = 0.2157752, metres = 10146.8 }
    , { lat = 47.9214543, lon = 0.2156478, metres = 10156.4 }
    , { lat = 47.9214887, lon = 0.2155472, metres = 10165 }
    , { lat = 47.9215721, lon = 0.2154755, metres = 10175.8 }
    , { lat = 47.9218212, lon = 0.2153837, metres = 10204.3 }
    , { lat = 47.9260093, lon = 0.2139097, metres = 10683.3 }
    , { lat = 47.9264407, lon = 0.2137269, metres = 10733.2 }
    , { lat = 47.9266615, lon = 0.2136082, metres = 10759.3 }
    , { lat = 47.9269838, lon = 0.2133944, metres = 10798.6 }
    , { lat = 47.9287512, lon = 0.2120577, metres = 11019.1 }
    , { lat = 47.9302293, lon = 0.2109885, metres = 11202 }
    , { lat = 47.9306537, lon = 0.2105946, metres = 11257.6 }
    , { lat = 47.9312869, lon = 0.2099065, metres = 11344.8 }
    , { lat = 47.9316138, lon = 0.2095919, metres = 11388.1 }
    , { lat = 47.9320658, lon = 0.2092226, metres = 11445.5 }
    , { lat = 47.9322813, lon = 0.2090683, metres = 11472.1 }
    , { lat = 47.9323748, lon = 0.2090281, metres = 11482.9 }
    , { lat = 47.9326245, lon = 0.2089887, metres = 11510.9 }
    , { lat = 47.9328918, lon = 0.2090088, metres = 11540.7 }
    , { lat = 47.9330412, lon = 0.2090582, metres = 11557.8 }
    , { lat = 47.9332434, lon = 0.2091785, metres = 11582 }
    , { lat = 47.933375, lon = 0.2092827, metres = 11598.6 }
    , { lat = 47.9334901, lon = 0.2094045, metres = 11614.3 }
    , { lat = 47.9342349, lon = 0.2104279, metres = 11727 }
    , { lat = 47.9344082, lon = 0.2106211, metres = 11751.1 }
    , { lat = 47.9346702, lon = 0.2108027, metres = 11783.3 }
    , { lat = 47.9348431, lon = 0.210868, metres = 11803.2 }
    , { lat = 47.9350007, lon = 0.2108956, metres = 11820.9 }
    , { lat = 47.9359723, lon = 0.2107801, metres = 11929.4 }
    , { lat = 47.9361889, lon = 0.2107277, metres = 11953.8 }
    , { lat = 47.9363808, lon = 0.2106433, metres = 11976.1 }
    , { lat = 47.9365128, lon = 0.2105356, metres = 11992.8 }
    , { lat = 47.936674, lon = 0.2103415, metres = 12015.9 }
    , { lat = 47.9368034, lon = 0.2101444, metres = 12036.5 }
    , { lat = 47.9371308, lon = 0.2095704, metres = 12092.7 }
    , { lat = 47.9373575, lon = 0.209303, metres = 12124.9 }
    , { lat = 47.9375328, lon = 0.2091535, metres = 12147.4 }
    , { lat = 47.9376705, lon = 0.209072, metres = 12163.9 }
    , { lat = 47.9378486, lon = 0.2090163, metres = 12184.2 }
    , { lat = 47.9380301, lon = 0.2089906, metres = 12204.5 }
    , { lat = 47.9381922, lon = 0.2089907, metres = 12222.5 }
    , { lat = 47.9383907, lon = 0.2090325, metres = 12244.9 }
    , { lat = 47.9385469, lon = 0.2090994, metres = 12263 }
    , { lat = 47.9387087, lon = 0.2092093, metres = 12282.8 }
    , { lat = 47.9388835, lon = 0.209376, metres = 12305.9 }
    , { lat = 47.9390165, lon = 0.2095461, metres = 12325.4 }
    , { lat = 47.9393413, lon = 0.2100998, metres = 12380.3 }
    , { lat = 47.9394584, lon = 0.2102717, metres = 12398.6 }
    , { lat = 47.9396613, lon = 0.210452, metres = 12424.9 }
    , { lat = 47.9399211, lon = 0.2105658, metres = 12455.1 }
    , { lat = 47.9400733, lon = 0.2105758, metres = 12472.1 }
    , { lat = 47.9402666, lon = 0.2105509, metres = 12493.7 }
    , { lat = 47.9418694, lon = 0.2102136, metres = 12673.9 }
    , { lat = 47.9421033, lon = 0.2102305, metres = 12700 }
    , { lat = 47.9426911, lon = 0.2103578, metres = 12766.1 }
    , { lat = 47.9429485, lon = 0.2103681, metres = 12794.8 }
    , { lat = 47.9431228, lon = 0.2103252, metres = 12814.5 }
    , { lat = 47.9436107, lon = 0.210139, metres = 12870.6 }
    , { lat = 47.94685, lon = 0.2088144, metres = 13244.4 }
    , { lat = 47.9469274, lon = 0.2087554, metres = 13254.1 }
    , { lat = 47.9469999, lon = 0.2086615, metres = 13264.8 }
    , { lat = 47.9471034, lon = 0.2083473, metres = 13291.1 }
    , { lat = 47.9472007, lon = 0.208204, metres = 13306.4 }
    , { lat = 47.947357, lon = 0.2081143, metres = 13325.1 }
    , { lat = 47.9480452, lon = 0.2079149, metres = 13403.2 }
    , { lat = 47.9481322, lon = 0.2078016, metres = 13416.2 }
    , { lat = 47.9481934, lon = 0.2075467, metres = 13436.5 }
    , { lat = 47.9482685, lon = 0.207464, metres = 13447.1 }
    , { lat = 47.9498718, lon = 0.2075404, metres = 13625.7 }
    ]


{-| From where it leaves the track before the Ford chicane to where it rejoins
it in the Dunlop curve, in the direction it is driven.
-}
pitLane : List PitPoint
pitLane =
    [ { lat = 47.9449898, lon = 0.2095768 }
    , { lat = 47.9456619, lon = 0.2093424 }
    , { lat = 47.9464269, lon = 0.2091177 }
    , { lat = 47.9473728, lon = 0.2087512 }
    , { lat = 47.9474362, lon = 0.2086716 }
    , { lat = 47.9475212, lon = 0.2083928 }
    , { lat = 47.9475803, lon = 0.208323 }
    , { lat = 47.9486271, lon = 0.2080295 }
    , { lat = 47.9488687, lon = 0.2078696 }
    , { lat = 47.9489655, lon = 0.2077579 }
    , { lat = 47.9491102, lon = 0.207703 }
    , { lat = 47.9526624, lon = 0.2078551 }
    , { lat = 47.9529572, lon = 0.2078882 }
    , { lat = 47.9538326, lon = 0.2080639 }
    , { lat = 47.9545181, lon = 0.2082552 }
    , { lat = 47.9550921, lon = 0.2085551 }
    , { lat = 47.9554103, lon = 0.2087638 }
    ]
