module Motorsport.Wec.Circuit.Cota.Geometry exposing (LapPoint, PitPoint, centreline, frame, pitLane)

{-| The Circuit of the Americas as OpenStreetMap surveys it (2026-10-19T03:01:20Z),
in WGS84 degrees, with how far round the lap each point stands. North is up and
`y` runs south in the drawing these degrees are projected into, which
`Motorsport.Wec.Circuit.Cota.Layout` writes. Written by
`app/scripts/cota-geometry.mjs`; edit that rather than this.

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
        { origin = { lat = 30.1394338, lon = -97.6434495 }
        , parallel = 30.135089049999973
        }


{-| The racing lap from the finish line, counter-clockwise, back to the finish
line. `metres` is how far round the lap a point is, stretched to the 5,515 m of
the circuit's own sector map. A sample read back off the line is stretched with
it, which is the scale the timing feed counts lap distances in.
-}
centreline : List LapPoint
centreline =
    [ { lat = 30.1335372, lon = -97.64225, metres = 0 }
    , { lat = 30.130423, lon = -97.637658, metres = 562.5 }
    , { lat = 30.1302904, lon = -97.6374452, metres = 587.8 }
    , { lat = 30.1300873, lon = -97.6370612, metres = 631.2 }
    , { lat = 30.1300504, lon = -97.6369333, metres = 644.3 }
    , { lat = 30.1300655, lon = -97.6368515, metres = 652.4 }
    , { lat = 30.1301246, lon = -97.6367764, metres = 662.4 }
    , { lat = 30.1302255, lon = -97.6367764, metres = 673.7 }
    , { lat = 30.1315732, lon = -97.6372961, metres = 832.1 }
    , { lat = 30.1317154, lon = -97.6373319, metres = 848.3 }
    , { lat = 30.1318439, lon = -97.6373396, metres = 862.7 }
    , { lat = 30.1319908, lon = -97.637326, metres = 879.1 }
    , { lat = 30.1321416, lon = -97.6372793, metres = 896.5 }
    , { lat = 30.1322845, lon = -97.637213, metres = 913.7 }
    , { lat = 30.1324756, lon = -97.6370752, metres = 938.8 }
    , { lat = 30.132638, lon = -97.6368767, metres = 965.3 }
    , { lat = 30.1333766, lon = -97.6354901, metres = 1122.2 }
    , { lat = 30.1335492, lon = -97.6352045, metres = 1155.8 }
    , { lat = 30.1336605, lon = -97.6350852, metres = 1172.8 }
    , { lat = 30.1337812, lon = -97.634998, metres = 1188.6 }
    , { lat = 30.1341825, lon = -97.6348183, metres = 1236.6 }
    , { lat = 30.134375, lon = -97.6346721, metres = 1262.4 }
    , { lat = 30.134433, lon = -97.634601, metres = 1271.8 }
    , { lat = 30.1344759, lon = -97.6345179, metres = 1281.1 }
    , { lat = 30.1346302, lon = -97.6340807, metres = 1326.7 }
    , { lat = 30.134752, lon = -97.6338956, metres = 1349.2 }
    , { lat = 30.1348494, lon = -97.6338031, metres = 1363.3 }
    , { lat = 30.1349712, lon = -97.6337468, metres = 1377.9 }
    , { lat = 30.1353854, lon = -97.6336756, metres = 1424.6 }
    , { lat = 30.1355644, lon = -97.6336247, metres = 1445.2 }
    , { lat = 30.135717, lon = -97.6335295, metres = 1464.5 }
    , { lat = 30.1358677, lon = -97.6333793, metres = 1486.7 }
    , { lat = 30.1360243, lon = -97.6331406, metres = 1515.7 }
    , { lat = 30.1361445, lon = -97.6328595, metres = 1545.9 }
    , { lat = 30.136189, lon = -97.6326779, metres = 1564.1 }
    , { lat = 30.1361994, lon = -97.63247, metres = 1584.2 }
    , { lat = 30.1361461, lon = -97.6322246, metres = 1608.7 }
    , { lat = 30.1357587, lon = -97.6312376, metres = 1713.2 }
    , { lat = 30.1357471, lon = -97.6311638, metres = 1720.4 }
    , { lat = 30.1357552, lon = -97.631086, metres = 1728 }
    , { lat = 30.1358817, lon = -97.6308245, metres = 1756.9 }
    , { lat = 30.1360382, lon = -97.6306046, metres = 1784.4 }
    , { lat = 30.1362226, lon = -97.6303998, metres = 1812.9 }
    , { lat = 30.1364604, lon = -97.6302036, metres = 1845.5 }
    , { lat = 30.1365474, lon = -97.630099, metres = 1859.5 }
    , { lat = 30.1366007, lon = -97.6299756, metres = 1872.8 }
    , { lat = 30.1366337, lon = -97.6298183, metres = 1888.5 }
    , { lat = 30.1366181, lon = -97.6295934, metres = 1910.3 }
    , { lat = 30.1365613, lon = -97.6294405, metres = 1926.4 }
    , { lat = 30.1364442, lon = -97.6292943, metres = 1945.7 }
    , { lat = 30.1362331, lon = -97.629128, metres = 1974.4 }
    , { lat = 30.1361925, lon = -97.6290556, metres = 1982.7 }
    , { lat = 30.1361728, lon = -97.6289268, metres = 1995.4 }
    , { lat = 30.1364969, lon = -97.627182, metres = 2167.4 }
    , { lat = 30.1365389, lon = -97.6270263, metres = 2183.2 }
    , { lat = 30.1366097, lon = -97.6269244, metres = 2195.9 }
    , { lat = 30.1390075, lon = -97.6246365, metres = 2542.3 }
    , { lat = 30.1391798, lon = -97.6244957, metres = 2565.9 }
    , { lat = 30.1392657, lon = -97.6244702, metres = 2575.8 }
    , { lat = 30.1393457, lon = -97.6244876, metres = 2585 }
    , { lat = 30.1394048, lon = -97.6245399, metres = 2593.3 }
    , { lat = 30.1394315, lon = -97.624607, metres = 2600.5 }
    , { lat = 30.1394277, lon = -97.6247282, metres = 2612.2 }
    , { lat = 30.1389119, lon = -97.6266401, metres = 2805.3 }
    , { lat = 30.1386023, lon = -97.6279209, metres = 2933.5 }
    , { lat = 30.1384306, lon = -97.6287121, metres = 3012.1 }
    , { lat = 30.1382079, lon = -97.6298319, metres = 3122.8 }
    , { lat = 30.1379876, lon = -97.6311194, metres = 3249.4 }
    , { lat = 30.1378078, lon = -97.6323773, metres = 3372.2 }
    , { lat = 30.1377235, lon = -97.6330797, metres = 3440.6 }
    , { lat = 30.1373905, lon = -97.6364617, metres = 3768.7 }
    , { lat = 30.1373717, lon = -97.6365509, metres = 3777.6 }
    , { lat = 30.1373149, lon = -97.6366099, metres = 3786.2 }
    , { lat = 30.1372661, lon = -97.6366193, metres = 3791.8 }
    , { lat = 30.137214, lon = -97.6366018, metres = 3797.8 }
    , { lat = 30.1366062, lon = -97.6360587, metres = 3883.5 }
    , { lat = 30.1362757, lon = -97.6357918, metres = 3928.4 }
    , { lat = 30.1358089, lon = -97.6354452, metres = 3990.3 }
    , { lat = 30.1356749, lon = -97.635431, metres = 4005.3 }
    , { lat = 30.1356134, lon = -97.6354512, metres = 4012.5 }
    , { lat = 30.1355647, lon = -97.63549, metres = 4019.1 }
    , { lat = 30.1355276, lon = -97.635545, metres = 4025.8 }
    , { lat = 30.1355113, lon = -97.6356121, metres = 4032.6 }
    , { lat = 30.1355368, lon = -97.636174, metres = 4086.8 }
    , { lat = 30.13556, lon = -97.6363148, metres = 4100.7 }
    , { lat = 30.1356273, lon = -97.6364288, metres = 4114.1 }
    , { lat = 30.1356901, lon = -97.6364801, metres = 4122.6 }
    , { lat = 30.1360182, lon = -97.6366219, metres = 4161.7 }
    , { lat = 30.1361347, lon = -97.6366942, metres = 4176.5 }
    , { lat = 30.136496, lon = -97.6370886, metres = 4231.9 }
    , { lat = 30.1365587, lon = -97.6372295, metres = 4247.2 }
    , { lat = 30.1365908, lon = -97.6374408, metres = 4267.9 }
    , { lat = 30.1366027, lon = -97.6376559, metres = 4288.7 }
    , { lat = 30.1365633, lon = -97.6377512, metres = 4299.1 }
    , { lat = 30.1364856, lon = -97.6377833, metres = 4308.4 }
    , { lat = 30.1363777, lon = -97.6377512, metres = 4321 }
    , { lat = 30.1350825, lon = -97.6368966, metres = 4487.2 }
    , { lat = 30.1348514, lon = -97.636803, metres = 4514.6 }
    , { lat = 30.134718, lon = -97.6367949, metres = 4529.5 }
    , { lat = 30.1344976, lon = -97.6368392, metres = 4554.5 }
    , { lat = 30.1341798, lon = -97.6369854, metres = 4592.6 }
    , { lat = 30.134065, lon = -97.6370658, metres = 4607.6 }
    , { lat = 30.1339897, lon = -97.6371407, metres = 4618.7 }
    , { lat = 30.1339414, lon = -97.6372252, metres = 4628.4 }
    , { lat = 30.1337783, lon = -97.6376194, metres = 4670.6 }
    , { lat = 30.1336718, lon = -97.637904, metres = 4700.5 }
    , { lat = 30.1336463, lon = -97.6380086, metres = 4711 }
    , { lat = 30.1336428, lon = -97.6382259, metres = 4731.9 }
    , { lat = 30.1336708, lon = -97.6384725, metres = 4755.9 }
    , { lat = 30.1337263, lon = -97.638702, metres = 4778.9 }
    , { lat = 30.1338353, lon = -97.6390037, metres = 4810.4 }
    , { lat = 30.1339142, lon = -97.6391432, metres = 4826.5 }
    , { lat = 30.1340105, lon = -97.6392599, metres = 4842.1 }
    , { lat = 30.1347215, lon = -97.6398419, metres = 4939.2 }
    , { lat = 30.1353995, lon = -97.6404623, metres = 5035.6 }
    , { lat = 30.1354719, lon = -97.6405554, metres = 5047.6 }
    , { lat = 30.1355055, lon = -97.6406292, metres = 5055.7 }
    , { lat = 30.1355194, lon = -97.6408008, metres = 5072.5 }
    , { lat = 30.1354765, lon = -97.6410114, metres = 5093.3 }
    , { lat = 30.1354116, lon = -97.6412072, metres = 5113.5 }
    , { lat = 30.1346085, lon = -97.6433055, metres = 5334.7 }
    , { lat = 30.1345382, lon = -97.6434133, metres = 5347.9 }
    , { lat = 30.1344767, lon = -97.6434441, metres = 5355.4 }
    , { lat = 30.1344106, lon = -97.6434468, metres = 5362.8 }
    , { lat = 30.1343631, lon = -97.6434294, metres = 5368.4 }
    , { lat = 30.1343016, lon = -97.6433771, metres = 5376.9 }
    , { lat = 30.1335372, lon = -97.64225, metres = 5515 }
    ]


{-| From where it leaves the lap 382 m before the finish line to where it merges
with it again 631 m after, in the direction it is driven. OpenStreetMap draws
the carriageway end to end, which reaches past the painted lines the sector map
puts at 116 m before the finish line and 390 m after it.
-}
pitLane : List PitPoint
pitLane =
    [ { lat = 30.1353383, lon = -97.6413928 }
    , { lat = 30.1347041, lon = -97.6428125 }
    , { lat = 30.1346414, lon = -97.6429265 }
    , { lat = 30.1345463, lon = -97.6430002 }
    , { lat = 30.1344095, lon = -97.6430284 }
    , { lat = 30.1342749, lon = -97.6430069 }
    , { lat = 30.1341671, lon = -97.6429439 }
    , { lat = 30.133984, lon = -97.6426984 }
    , { lat = 30.1314643, lon = -97.6389855 }
    , { lat = 30.1309938, lon = -97.6383688 }
    , { lat = 30.1300873, lon = -97.6370612 }
    ]
