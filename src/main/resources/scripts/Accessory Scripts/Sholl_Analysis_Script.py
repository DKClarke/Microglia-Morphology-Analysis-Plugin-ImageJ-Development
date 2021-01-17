#@LogService log

from ij import IJ
from sc.fiji.snt import Tree
from sc.fiji.snt.analysis.sholl import *
from sc.fiji.snt.analysis.sholl.gui import *
from sc.fiji.snt.analysis.sholl.math import LinearProfileStats
from sc.fiji.snt.analysis.sholl.math import NormalizedProfileStats
from sc.fiji.snt.analysis.sholl.math import ShollStats
from sc.fiji.snt.analysis.sholl.parsers import *
import os
import csv

def main(imp, startRad, stepSize):

    # We may want to set specific options depending on whether we are parsing a
    # 2D or a 3D image. If the image has multiple channels/time points, we set
    # the C,T position to be analyzed by activating them. The channel and frame
    # will be stored in the profile properties map and can be retrieved later):
    parser = ImageParser2D(imp)
    parser.setRadiiSpan(0, ImageParser2D.MEAN) # mean of 4 measurements at every radius
    parser.setPosition(1, 1, 1) # channel, frame, Z-slice

    # Center: the x,y,z coordinates of center of analysis. In a real-case usage
    # these would be retrieved from ROIs or a centroid of a segmentation routine.
    # If no ROI exists coordinates can be set in spatially calibrated units
    # (floats) or pixel coordinates (integers):
    parser.setCenterFromROI()

    # Sampling distances: start radius (sr), end radius (er), and step size (ss).
    # A step size of zero would mean 'continuos sampling'. Note that end radius
    # could also be set programmatically, e.g., from a ROI
    parser.setRadii(startRad, stepSize, parser.maxPossibleRadius()) # (sr, er, ss)

    # We could now set further options as we would do in the dialog prompt:
    parser.setHemiShells('none')
    # (...)

    # Parse the image. This may take a while depending on image size. 3D images
    # will be parsed using the number of threads specified in ImageJ's settings:
    parser.parse()
    if not parser.successful():
        log.error(imp.getTitle() + " could not be parsed!!!")
        return

    # We can e.g., access the 'Sholl mask', a synthetic image in which foreground
    # pixels have been assigned the no. of intersections:
    #parser.getMask().show()

    # Now we can access the Sholl profile:
    profile = parser.getProfile()
    if profile.isEmpty():
        log.error("All intersection counts were zero! Invalid threshold range!?")
        return

    lStats = LinearProfileStats(profile)

    bestDegree2 = lStats.findBestFit(0, # lowest degree
                            30,     # highest degree
                            0.70,   # lowest value for adjusted RSquared
                            0.05)   # the two-sample K-S p-value used to discard 'unsuitable fits'
    print("The automated 'Best polynomial': " + str(bestDegree2))

    dataTypeDict = {'Sampled': False, 'Fitted': True}

    dfColsList = ['Min', 'Max', 'Mean', 'Median', 'Sum', 'Variance', 'Sum squared', 'Intersect. radii', 
        'I branches', 'Ramification index', 'Centroid', 'Centroid (polygon)', 'Enclosing radius', 'Maxima', 
        'Centered maximum', 'Kurtosis', 'Skewness']

    allDfCols = list()
    allDfData = list()
    for analysisTypeName in dataTypeDict:
        analysisType = dataTypeDict[analysisTypeName]
        do = False
        if analysisType == False or (analysisType == True and str(bestDegree2) != '-1'):
            print("  Min (" + analysisTypeName + ") = " + str(lStats.getMin(analysisType)))
            print("  Max (" + analysisTypeName + ") = " + str(lStats.getMax(analysisType)))
            print("  Mean (" + analysisTypeName + ") = " + str(lStats.getMean(analysisType)))
            print("  Median (" + analysisTypeName + ") = " + str(lStats.getMedian(analysisType)))
            print("  Sum (" + analysisTypeName + ") = " + str(lStats.getSum(analysisType)))
            print("  Variance (" + analysisTypeName + ") = " + str(lStats.getVariance(analysisType)))
            print("  Sum squared (" + analysisTypeName + ") = " + str(lStats.getSumSq(analysisType)))
            print("  Intersect. radii (" + analysisTypeName + ") = " + str(lStats.getIntersectingRadii(analysisType)))
            print("  I branches (" + analysisTypeName + ") = " + str(lStats.getPrimaryBranches(analysisType)))
            print("  Ramification index (" + analysisTypeName + ") = " + str(lStats.getRamificationIndex(analysisType)))
            print("  Centroid (" + analysisTypeName + ") = " + str(lStats.getCentroid(analysisType)))
            print("  Centroid (polygon) (" + analysisTypeName + ") = " + str(lStats.getPolygonCentroid(analysisType)))
            print("  Enclosing radius (" + analysisTypeName + ") = " + str(lStats.getEnclosingRadius(analysisType, 1)))
            print("  Maxima (" + analysisTypeName + ") = " + str(lStats.getMaxima(analysisType)))
            print("  Centered maximum (" + analysisTypeName + ") = " + str(lStats.getCenteredMaximum(analysisType)))
            print("  Kurtosis (" + analysisTypeName + ") = " + str(lStats.getKurtosis(analysisType)))
            print("  Skewness (" + analysisTypeName + ") = " + str(lStats.getSkewness(analysisType)))

            dfValsList = [lStats.getMin(analysisType), lStats.getMax(analysisType), lStats.getMean(analysisType), 
                lStats.getMedian(analysisType), lStats.getSum(analysisType), lStats.getVariance(analysisType), 
                lStats.getSumSq(analysisType), lStats.getIntersectingRadii(analysisType), lStats.getPrimaryBranches(analysisType), 
                lStats.getRamificationIndex(analysisType),lStats.getCentroid(analysisType), lStats.getPolygonCentroid(analysisType),
                lStats.getEnclosingRadius(analysisType, 1), lStats.getMaxima(analysisType), lStats.getCenteredMaximum(analysisType),
                lStats.getKurtosis(analysisType), lStats.getSkewness(analysisType)]

        else:

            dfValsList = ['NA' for col in dfColsList]

        thisColsList = [col + " (" + analysisTypeName + ")" for col in dfColsList]
        allDfCols = allDfCols + thisColsList
        allDfData = allDfData + dfValsList

    csv_filename = os.path.join(str('/Users/devin.clarke/Desktop/'), 'csv_filename.csv')
    with open(csv_filename, 'wb') as f:
                writer = csv.writer(f)
                writer.writerow(allDfCols)
                writer.writerow(allDfData)


    # Determine Sholl decay using area as a normalizer. The choice between
    # log-log or semi-log method is automatically made by the program
    nStats = NormalizedProfileStats(profile, ShollStats.AREA)

    print("Chosen method: " + str(nStats.getMethodDescription()))
    print( "Sholl decay: " + str(nStats.getShollDecay()))
    print( "Determination ratio: " + str(nStats.getDeterminationRatio()))

    dataSubset = [[10,90]]

    for it in dataSubset:
        nStats.restrictRegToPercentile(it[0], it[1])
        print('R^2 P' + str(it) + ": " + str(nStats.getRSquaredOfFit()))
        nStats.resetRegression()


    # We can now access all the measured data stored in 'profile': Let's display
    # the sampling shells and the detected sites of intersections (NB: If the
    # image already has an overlay, it will be cleared):
    #profile.getROIs(imp)
    
    # For now, lets's perform a minor cleanup of the data and plot it without
    # doing any polynomial regression. Have a look at Sholl_Extensive_Stats_Demo
    # script for details on how to analyze profiles with detailed granularity
    #profile.trimZeroCounts()
    #profile.plot().show()
    

# For this demo we are going to use the ddaC sample image
args = getArgument()
#d = dict(x.split("=") for x in args.split(","))
d = [x.split("=") for x in args.split(",")]
arg_dict = dict(d)
startRad = float(arg_dict[arg_dict.keys()[0]])
stepSize = float(arg_dict[arg_dict.keys()[1]])

imp = IJ.getImage()
main(imp, startRad, stepSize)
