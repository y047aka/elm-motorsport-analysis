module Motorsport.Wec.Circuit.LeMans.Geometry exposing (centreline, pitLane)

{-| The Circuit de la Sarthe as OpenStreetMap surveys it (2026-09-26T15:42:21Z), in
metres, with north up and `y` running south. Written by
`app/scripts/le-mans-geometry.mjs`; edit that rather than this.

Map data © OpenStreetMap contributors, under the Open Database License.

@docs centreline, pitLane

-}

import Motorsport.Circuit.Shape exposing (Mark, Point)


{-| The racing lap from the finish line, clockwise, back to the finish line.
`metres` is how far round the lap a point is, stretched to the 13,625.7 m of
Al Kamel's circuit maps.
-}
centreline : List Mark
centreline =
    [ { x = 6.1, y = 1334.4, metres = 0 }
    , { x = 16.6, y = 1024.9, metres = 310 }
    , { x = 19.2, y = 990.5, metres = 344.5 }
    , { x = 23.2, y = 958, metres = 377.3 }
    , { x = 31.1, y = 913.8, metres = 422.3 }
    , { x = 43.5, y = 857.7, metres = 479.8 }
    , { x = 52.9, y = 824.5, metres = 514.3 }
    , { x = 65.4, y = 787.7, metres = 553.2 }
    , { x = 85.4, y = 738.8, metres = 606.1 }
    , { x = 97.2, y = 718.5, metres = 629.6 }
    , { x = 112.8, y = 698.6, metres = 654.9 }
    , { x = 129.2, y = 683.2, metres = 677.5 }
    , { x = 144.4, y = 672.6, metres = 696.1 }
    , { x = 256.6, y = 604, metres = 827.7 }
    , { x = 263.9, y = 597.6, metres = 837.5 }
    , { x = 266.5, y = 591.5, metres = 844.1 }
    , { x = 267.1, y = 583.6, metres = 852.2 }
    , { x = 258.1, y = 539.6, metres = 897.2 }
    , { x = 260.5, y = 531, metres = 906.2 }
    , { x = 266, y = 523.4, metres = 915.7 }
    , { x = 390.6, y = 443.4, metres = 1063.9 }
    , { x = 412.6, y = 427.8, metres = 1090.8 }
    , { x = 434.4, y = 405.6, metres = 1122.1 }
    , { x = 479.2, y = 342.8, metres = 1199.4 }
    , { x = 497.8, y = 324.9, metres = 1225.2 }
    , { x = 511.9, y = 315.2, metres = 1242.4 }
    , { x = 548.9, y = 298, metres = 1283.2 }
    , { x = 574.3, y = 290.2, metres = 1309.9 }
    , { x = 593.9, y = 287.8, metres = 1329.7 }
    , { x = 694.5, y = 282.8, metres = 1430.5 }
    , { x = 711.3, y = 278.3, metres = 1447.9 }
    , { x = 724.9, y = 269.8, metres = 1464 }
    , { x = 741.3, y = 253.1, metres = 1487.6 }
    , { x = 753.2, y = 228.7, metres = 1514.8 }
    , { x = 756.1, y = 217.5, metres = 1526.5 }
    , { x = 757, y = 186.8, metres = 1557.2 }
    , { x = 759.9, y = 167.9, metres = 1576.3 }
    , { x = 767, y = 147.8, metres = 1597.7 }
    , { x = 774.1, y = 136.2, metres = 1611.3 }
    , { x = 791.3, y = 120.7, metres = 1634.5 }
    , { x = 850.6, y = 75.8, metres = 1709 }
    , { x = 869.8, y = 64.4, metres = 1731.4 }
    , { x = 900.3, y = 49.6, metres = 1765.3 }
    , { x = 1026.5, y = 1.9, metres = 1900.4 }
    , { x = 1036.5, y = 0, metres = 1910.5 }
    , { x = 1050, y = 1.4, metres = 1924.2 }
    , { x = 1060.8, y = 5.5, metres = 1935.7 }
    , { x = 1094.8, y = 24.3, metres = 1974.6 }
    , { x = 1147.2, y = 57.4, metres = 2036.7 }
    , { x = 1186.3, y = 84.7, metres = 2084.4 }
    , { x = 1222.5, y = 116.8, metres = 2132.9 }
    , { x = 1246, y = 140, metres = 2165.9 }
    , { x = 1283.7, y = 187.2, metres = 2226.4 }
    , { x = 1441.6, y = 438, metres = 2523.1 }
    , { x = 1469.8, y = 490.5, metres = 2582.7 }
    , { x = 1493.9, y = 545.1, metres = 2642.6 }
    , { x = 1506.2, y = 578.8, metres = 2678.4 }
    , { x = 1567.4, y = 767.9, metres = 2877.4 }
    , { x = 1919.7, y = 1864.4, metres = 4030.3 }
    , { x = 1921.4, y = 1881.6, metres = 4047.6 }
    , { x = 1919.6, y = 1891.8, metres = 4058 }
    , { x = 1914.6, y = 1902.8, metres = 4070.1 }
    , { x = 1901.4, y = 1919.6, metres = 4091.6 }
    , { x = 1896.5, y = 1930.3, metres = 4103.4 }
    , { x = 1894.9, y = 1944.9, metres = 4118.2 }
    , { x = 1897.3, y = 1960.3, metres = 4133.9 }
    , { x = 1901, y = 1968.4, metres = 4142.7 }
    , { x = 1906.2, y = 1974.7, metres = 4150.9 }
    , { x = 1953.6, y = 2016.5, metres = 4214.2 }
    , { x = 1966.5, y = 2029.9, metres = 4232.8 }
    , { x = 1975.3, y = 2043.9, metres = 4249.3 }
    , { x = 1985.4, y = 2068.1, metres = 4275.7 }
    , { x = 2515.6, y = 3713.4, metres = 6006.1 }
    , { x = 2521, y = 3721.4, metres = 6015.8 }
    , { x = 2532.4, y = 3730.8, metres = 6030.6 }
    , { x = 2542.6, y = 3736.6, metres = 6042.4 }
    , { x = 2571.2, y = 3746.5, metres = 6072.6 }
    , { x = 2577.5, y = 3750.9, metres = 6080.4 }
    , { x = 2585.4, y = 3759.6, metres = 6092.2 }
    , { x = 2591.7, y = 3772.9, metres = 6107 }
    , { x = 2593.1, y = 3786.6, metres = 6120.9 }
    , { x = 2591.1, y = 3799.6, metres = 6134.1 }
    , { x = 2576.2, y = 3855.1, metres = 6191.6 }
    , { x = 2574.5, y = 3874.6, metres = 6211.2 }
    , { x = 2575.2, y = 3894.5, metres = 6231.2 }
    , { x = 2579.7, y = 3912.1, metres = 6249.3 }
    , { x = 2637.4, y = 4091.8, metres = 6438.3 }
    , { x = 2645, y = 4123.4, metres = 6470.8 }
    , { x = 2652.3, y = 4173.3, metres = 6521.3 }
    , { x = 2690.3, y = 4799.8, metres = 7149.7 }
    , { x = 2712.4, y = 5213, metres = 7563.8 }
    , { x = 2710.7, y = 5243.5, metres = 7594.4 }
    , { x = 2707, y = 5267.1, metres = 7618.4 }
    , { x = 2676.6, y = 5376.7, metres = 7732.2 }
    , { x = 2673.5, y = 5381.2, metres = 7737.7 }
    , { x = 2665.7, y = 5385.6, metres = 7746.7 }
    , { x = 2657.5, y = 5386.8, metres = 7755.1 }
    , { x = 2651.1, y = 5385.4, metres = 7761.7 }
    , { x = 1999.1, y = 5207.2, metres = 8438.2 }
    , { x = 1961.8, y = 5195.5, metres = 8477.4 }
    , { x = 1926.9, y = 5181.5, metres = 8515.1 }
    , { x = 1899.7, y = 5168.2, metres = 8545.3 }
    , { x = 1471.5, y = 4948.6, metres = 9027.1 }
    , { x = 1427.7, y = 4920.9, metres = 9079 }
    , { x = 1127.6, y = 4698.6, metres = 9452.9 }
    , { x = 998.1, y = 4593, metres = 9620.1 }
    , { x = 978.5, y = 4571.9, metres = 9649 }
    , { x = 964.9, y = 4547, metres = 9677.4 }
    , { x = 923.2, y = 4416, metres = 9815.1 }
    , { x = 914.9, y = 4403.9, metres = 9829.8 }
    , { x = 901.7, y = 4395.7, metres = 9845.5 }
    , { x = 885.6, y = 4393.8, metres = 9861.8 }
    , { x = 869, y = 4397.5, metres = 9878.9 }
    , { x = 619.5, y = 4494.3, metres = 10146.8 }
    , { x = 610, y = 4494.3, metres = 10156.4 }
    , { x = 602.5, y = 4490.4, metres = 10165 }
    , { x = 597.2, y = 4481.2, metres = 10175.8 }
    , { x = 590.3, y = 4453.5, metres = 10204.3 }
    , { x = 480.5, y = 3987.8, metres = 10683.3 }
    , { x = 466.9, y = 3939.8, metres = 10733.2 }
    , { x = 458.1, y = 3915.3, metres = 10759.3 }
    , { x = 442.2, y = 3879.4, metres = 10798.6 }
    , { x = 342.6, y = 3682.9, metres = 11019.1 }
    , { x = 263, y = 3518.5, metres = 11202 }
    , { x = 233.6, y = 3471.3, metres = 11257.6 }
    , { x = 182.4, y = 3400.9, metres = 11344.8 }
    , { x = 158.9, y = 3364.6, metres = 11388.1 }
    , { x = 131.4, y = 3314.3, metres = 11445.5 }
    , { x = 119.9, y = 3290.4, metres = 11472.1 }
    , { x = 116.9, y = 3280, metres = 11482.9 }
    , { x = 114, y = 3252.2, metres = 11510.9 }
    , { x = 115.5, y = 3222.5, metres = 11540.7 }
    , { x = 119.2, y = 3205.9, metres = 11557.8 }
    , { x = 128.1, y = 3183.4, metres = 11582 }
    , { x = 135.9, y = 3168.7, metres = 11598.6 }
    , { x = 145, y = 3155.9, metres = 11614.3 }
    , { x = 221.2, y = 3073.1, metres = 11727 }
    , { x = 235.6, y = 3053.9, metres = 11751.1 }
    , { x = 249.1, y = 3024.7, metres = 11783.3 }
    , { x = 254, y = 3005.5, metres = 11803.2 }
    , { x = 256, y = 2988, metres = 11820.9 }
    , { x = 247.4, y = 2879.9, metres = 11929.4 }
    , { x = 243.5, y = 2855.9, metres = 11953.8 }
    , { x = 237.2, y = 2834.5, metres = 11976.1 }
    , { x = 229.2, y = 2819.8, metres = 11992.8 }
    , { x = 214.8, y = 2801.9, metres = 12015.9 }
    , { x = 200.1, y = 2787.5, metres = 12036.5 }
    , { x = 157.3, y = 2751.1, metres = 12092.7 }
    , { x = 137.4, y = 2725.9, metres = 12124.9 }
    , { x = 126.3, y = 2706.4, metres = 12147.4 }
    , { x = 120.2, y = 2691.1, metres = 12163.9 }
    , { x = 116.1, y = 2671.3, metres = 12184.2 }
    , { x = 114.1, y = 2651.1, metres = 12204.5 }
    , { x = 114.1, y = 2633.1, metres = 12222.5 }
    , { x = 117.3, y = 2611, metres = 12244.9 }
    , { x = 122.2, y = 2593.7, metres = 12263 }
    , { x = 130.4, y = 2575.7, metres = 12282.8 }
    , { x = 142.8, y = 2556.2, metres = 12305.9 }
    , { x = 155.5, y = 2541.4, metres = 12325.4 }
    , { x = 196.8, y = 2505.3, metres = 12380.3 }
    , { x = 209.6, y = 2492.3, metres = 12398.6 }
    , { x = 223, y = 2469.7, metres = 12424.9 }
    , { x = 231.5, y = 2440.9, metres = 12455.1 }
    , { x = 232.2, y = 2423.9, metres = 12472.1 }
    , { x = 230.4, y = 2402.4, metres = 12493.7 }
    , { x = 205.2, y = 2224.2, metres = 12673.9 }
    , { x = 206.5, y = 2198.2, metres = 12700 }
    , { x = 216, y = 2132.8, metres = 12766.1 }
    , { x = 216.7, y = 2104.2, metres = 12794.8 }
    , { x = 213.5, y = 2084.8, metres = 12814.5 }
    , { x = 199.7, y = 2030.6, metres = 12870.6 }
    , { x = 101, y = 1670.4, metres = 13244.4 }
    , { x = 96.6, y = 1661.8, metres = 13254.1 }
    , { x = 89.6, y = 1653.7, metres = 13264.8 }
    , { x = 66.2, y = 1642.2, metres = 13291.1 }
    , { x = 55.6, y = 1631.4, metres = 13306.4 }
    , { x = 48.9, y = 1614, metres = 13325.1 }
    , { x = 34, y = 1537.5, metres = 13403.2 }
    , { x = 25.6, y = 1527.8, metres = 13416.2 }
    , { x = 6.6, y = 1521, metres = 13436.5 }
    , { x = 0.4, y = 1512.7, metres = 13447.1 }
    , { x = 6.1, y = 1334.4, metres = 13625.7 }
    ]


{-| From where it leaves the track before the Ford chicane to where it rejoins
it in the Dunlop curve, in the direction it is driven.
-}
pitLane : List Point
pitLane =
    [ { x = 157.8, y = 1877.2 }
    , { x = 140.3, y = 1802.5 }
    , { x = 123.6, y = 1717.4 }
    , { x = 96.3, y = 1612.3 }
    , { x = 90.4, y = 1605.2 }
    , { x = 69.6, y = 1595.8 }
    , { x = 64.4, y = 1589.2 }
    , { x = 42.6, y = 1472.8 }
    , { x = 30.6, y = 1445.9 }
    , { x = 22.3, y = 1435.2 }
    , { x = 18.2, y = 1419.1 }
    , { x = 29.6, y = 1024.1 }
    , { x = 32, y = 991.3 }
    , { x = 45.1, y = 894 }
    , { x = 59.4, y = 817.7 }
    , { x = 81.7, y = 753.9 }
    , { x = 97.2, y = 718.5 }
    ]
