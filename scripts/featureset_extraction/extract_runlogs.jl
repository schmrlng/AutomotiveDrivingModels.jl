using AutomotiveDrivingModels
using AutomotiveDrivingModels.StreetNetworks.RoadNetwork

include(Pkg.dir("AutomotiveDrivingModels", "src", "io", "filesystem_utils.jl"))

const STREETNET_CACHE = Dict{AbstractString, StreetNetwork}()
const PRIMARYDATA_DIR = "/media/tim/DATAPART1/Data/Bosch/processed/primarydata/"
const OUTPUT_DIR = "/media/tim/DATAPART1/PublicationData/2015_TrafficEvolutionModels/realworld/"
const RUNLOG_OUTPUT_DIR = joinpath(OUTPUT_DIR, "runlogs")
const RUNLOG_DIR = joinpath(OUTPUT_DIR, "runlogs")

# OLD:
# CSVFileSet(RunLogs.ID_EGO,
            #     "/media/tim/DATAPART1/Data/Bosch/source2/2014-08-03-12-01-09-edited.csv",
            #     "its_inner_loop_v1_2",
            #     Int[],
            #     Int[],
            #     [4372,4482,4831,4976],
            #     [417,4266],
            #     [1,416,4483,4830,4977,5900]
            #     ),
            # CSVFileSet(RunLogs.ID_EGO,
            #     "/media/tim/DATAPART1/Data/Bosch/source2/2014-08-03-11-52-58-raw.csv",
            #     "its_inner_loop_v1_2",
            #     Int[],
            #     Int[],
            #     [1,153,359,518],
            #     [1101,1700],
            #     [154,358,519,1100,2494,3940]
            #     ),
            # CSVFileSet(RunLogs.ID_EGO,
            #     "/media/tim/DATAPART1/Data/Bosch/source2/2014-08-03-12-12-53-raw.csv",
            #     "its_inner_loop_v1_2",
            #     Int[],
            #     Int[],
            #     [1740,1892],
            #     [956,1348],
            #     [1624,1739,1893,3060]
            #     ),
            # CSVFileSet(RunLogs.ID_EGO,
            #     "/media/tim/DATAPART1/Data/Bosch/source2/2014-08-03-12-16-14-raw.csv",
            #     "its_both_loops_v3_smoothed",
            #     Int[],
            #     Int[],
            #     Int[],
            #     [2477,3918],
            #     [1,1020,1540,1936,2120,2476]
            #     ),
            # CSVFileSet(RunLogs.ID_EGO,
            #     "/media/tim/DATAPART1/Data/Bosch/source2/2014-08-03-12-20-36-raw.csv",
            #     "its_inner_loop_v1_2",
            #     Int[],
            #     Int[],
            #     [2733,2898],
            #     [68,2100],
            #     [2506,2732,2899,3292]
            #     ),
            # CSVFileSet(RunLogs.ID_EGO,
            #     "/media/tim/DATAPART1/Data/Bosch/source2/2014-08-03-12-54-24-raw.csv",
            #     "its_inner_loop_v1_2",
            #     Int[],
            #     Int[],
            #     Int[],
            #     [3166,3534,3972,6272,6448,7678,8036,8228,9031,9262],
            #     [8235,8500,8730,9030]
            #     ),
            # CSVFileSet(RunLogs.ID_EGO,
            #     "/media/tim/DATAPART1/Data/Bosch/source2/2014-08-06-16-11-51_large_loop_3-raw.csv",
            #     "detroit_v4",
            #     Int[],
            #     Int[],
            #     Int[],
            #     Int[],
            #     [1,1618,1642,1834,1844,1902,3810,4232,6618,8588]
            #     ),


const CSVFILESETS = (
            CSVFileSet(RunLogs.ID_EGO,
                "/media/tim/DATAPART1/Data/Bosch/philippruns_20150324/philippdrive01_2015-03-24-15-21-12-raw.csv",
                "280_pagemill_to_92",
                Int[],
                [128,297,475,673,3520,3671,4363,4559,5724,5833,6816,6937,7086,7343,7650,7765,8102,8283,8826,9333,9922,10095],
                [2641,2833,3790,3981,5026,5255,10184,10321],
                [9816,9921],
                [1,127,298,475,1900,2293,5256,5723,6466,6815,6938,7085,7343,7649,7766,8101,8754,8825],
                [674,1899,2294,2641,2834,3519,3672,3789,3982,4363,4560,5025,5834,6465,8284,8753,9334,9815,10096,10183]
                ),
            CSVFileSet(RunLogs.ID_EGO,
                "/media/tim/DATAPART1/Data/Bosch/philippruns_20150324/philippdrive03_2015-03-24-15-37-18-raw.csv",
                "280_pagemill_to_92", # 16
                Int[],
                [1182,1386,1425,1562,1657,1826,3331,3568,4929,5238,5691,5840,5899,6112,7913,8040,8407,8532],
                [3191,3330,3785,3974,4027,4212,6275,6778,8111,8278],
                [7712,7888,8533,8722],
                [1387,1424,5239,5690,5841,5898,7889,7912,9055,9160],
                [1,1182,1563,1656,1827,3190,3569,3784,3975,4026,4213,4928,6113,6274,8041,8110,8279,8406,8723,9054]
                ),
            CSVFileSet(RunLogs.ID_EGO,
                "/media/tim/DATAPART1/Data/Bosch/philippruns_20150324/philippdrive04_2015-03-24-15-47-10-raw.csv",
                "280_pagemill_to_92",
                Int[],
                [811,944,945,1148],
                Int[],
                Int[],
                Int[],
                [1,810]
                ),
            CSVFileSet(RunLogs.ID_EGO,
                "/media/tim/DATAPART1/Data/Bosch/philippruns_20150324/philippdrive05_2015-03-24-15-48-42-raw.csv",
                "280_pagemill_to_92",
                Int[],
                [149,314,628,934,1571,1683,2819,3032,3107,3308],
                Int[],
                Int[],
                [1,148,935,1570,1684,2818,3033,3106,3309,4434],
                [315,626]
                ),
            CSVFileSet(RunLogs.ID_EGO,
                "/media/tim/DATAPART1/Data/Bosch/philippruns_20150324/philippdrive07_2015-03-24-15-57-42-raw.csv",
                "280_pagemill_to_92",
                Int[],
                [31,138,965,1176,1481,1668,2753,2936,4135,4350,4351,4530,4672,4880,5271,5516,5856,6026,6195,6412,7775,7938,8519,8608],
                Int[],
                [6989,7156],
                [481,964,1177,1480,1669,2752,2937,4134,4531,4672,4999,5156,7157,7774,7939,8518],
                [1,30,139,480,4881,4998,5157,5270,5517,5856,6027,6194,6413,6988]
                ),
            CSVFileSet(RunLogs.ID_EGO,
                "/media/tim/DATAPART1/Data/Bosch/source4/2015-02-05-14-03-40_driving_style_data_martin-raw.csv",
                "280_pagemill_to_92",
                Int[],
                Int[553,682,2636,2821], # lanechange normal
                Int[762,915,4717,4926], # lanechanges postpass
                Int[1599,1716,2340,2549,3472,3611,4455,4611], # lanechanges arbitrary
                Int[2550,2635], # car follow
                Int[41,553,683,761,916,1598,1717,2339,2822,3471,3612,4454,4612,4716,4927,8838], # free flow
                ),

            CSVFileSet(RunLogs.ID_EGO,
                "/media/tim/DATAPART1/Data/Bosch/source5/2015-12-14-14-39-22_planning_stripped-raw.csv",
                "???",
                [12206,17301], # only extract these frames
                Int[], # lanechange normal
                Int[], # lanechanges postpass
                Int[], # lanechanges arbitrary
                Int[], # car follow
                Int[], # free flow
                ),
            CSVFileSet(RunLogs.ID_EGO,
                "/media/tim/DATAPART1/Data/Bosch/source5/2015-12-14-15-04-57_92_to_pagemill_manual_drive_planning_stripped-raw.csv",
                "???",
                [1499,2578,2747,6168], # only extract these frames
                Int[], # lanechange normal
                Int[], # lanechanges postpass
                Int[], # lanechanges arbitrary
                Int[], # car follow
                Int[], # free flow
                ),
            CSVFileSet(RunLogs.ID_EGO,
                "/media/tim/DATAPART1/Data/Bosch/source5/2015-12-22-13-50-09_280N_manual_drive_lane_changes_planning_stripped-raw.csv",
                "???",
                [1105, 7030, 8324, 8681, 10041, 12700], # only extract these frames
                Int[], # lanechange normal
                Int[], # lanechanges postpass
                Int[], # lanechanges arbitrary
                Int[], # car follow
                Int[], # free flow
                ),
            CSVFileSet(RunLogs.ID_EGO,
                "/media/tim/DATAPART1/Data/Bosch/source5/2015-12-22-14-05-41_280S_manual_drive_lane_changes_planning_stripped-raw.csv",
                "???",
                [1,1518,1949,3123,5399,12802], # only extract these frames
                Int[], # lanechange normal
                Int[], # lanechanges postpass
                Int[], # lanechanges arbitrary
                Int[], # car follow
                Int[], # free flow
                ),
            CSVFileSet(RunLogs.ID_EGO,
                        "/media/tim/DATAPART1/Data/Bosch/philippruns_20160223/manual_2016-02-23-15-07-30_planning_stripped-raw.csv",
                        "???",
                        Int[],
                        Int[], # lanechange normal
                        Int[], # lanechanges postpass
                        Int[], # lanechanges arbitrary
                        Int[], # car follow
                        Int[], # free flow
                        ),
            CSVFileSet(RunLogs.ID_EGO,
                        "/media/tim/DATAPART1/Data/Bosch/philippruns_20160223/manual2_2016-02-23-15-42-56_planning_stripped-raw.csv",
                        "???",
                        Int[],
                        Int[], # lanechange normal
                        Int[], # lanechanges postpass
                        Int[], # lanechanges arbitrary
                        Int[], # car follow
                        Int[], # free flow
                        ),
            CSVFileSet(RunLogs.ID_EGO,
                        "/media/tim/DATAPART1/Data/Bosch/philippruns_20160223/manual2_2016-02-23-15-55-53_planning_stripped-raw.csv",
                        "???",
                        Int[],
                        Int[], # lanechange normal
                        Int[], # lanechanges postpass
                        Int[], # lanechanges arbitrary
                        Int[], # car follow
                        Int[], # free flow
                        ),
            CSVFileSet(RunLogs.ID_EGO,
                        "/media/tim/DATAPART1/Data/Bosch/runs_201605/2016-05-25-14-55-45-raw.csv",
                        "???",
                        Int[],
                        Int[], # lanechange normal
                        Int[], # lanechanges postpass
                        Int[], # lanechanges arbitrary
                        Int[], # car follow
                        Int[], # free flow
                        ),
        )

#############################################

@assert(isdir(OUTPUT_DIR))
if !isdir(RUNLOG_OUTPUT_DIR)
    mkdir(RUNLOG_OUTPUT_DIR)
end

#############################################

extract_params = PrimaryDataExtractionParams()

tot_frames = 0
tot_freeflow = 0
tot_following = 0
tot_lanechange = 0

tic()
for (csvfileset_index, csvfileset) in enumerate(CSVFILESETS)

    println("csvfileset ", csvfileset_index, " / ", length(CSVFILESETS))
    csvfilename = csvfileset.csvfile
    csvfilebase = basename(csvfilename)
    csvfilebase_noext = splitext(csvfilebase)[1]

    header, trajdata, sn = load_header_trajdata_and_streetmap(csvfilename)
    # extract_params.csvfileset = csvfileset
    extract_params.frameinds = csvfileset.only_extract_these_frame_ranges
    runlogs = extract_runlogs(trajdata, sn, extract_params, header)::AbstractVector{RunLog}

    for (i,runlog) in enumerate(runlogs)
        runlogname = joinpath(RUNLOG_OUTPUT_DIR, @sprintf("primarydata_%s_%d.jld", splitext(csvfilebase)[1], i))
        JLD.save(runlogname, "runlog", runlog)
    end

    for runlog in runlogs

        tot_frames += nframes(runlog)
        for frame in 1 : nframes(runlog)
            colset = colset2id(runlog, ID_EGO, frame)
            tot_freeflow += is_behavior_flag_set(runlog, colset, frame, ContextClass.FREEFLOW)
            tot_following += is_behavior_flag_set(runlog, colset, frame, ContextClass.FOLLOWING)
            tot_lanechange += is_behavior_flag_set(runlog, colset, frame, ContextClass.LANECHANGE)
        end
    end
end
toc()

println("tot_frames:     ", tot_frames)
println("tot_freeflow:   ", tot_freeflow)
println("tot_following:  ", tot_following)
println("tot_lanechange: ", tot_lanechange)