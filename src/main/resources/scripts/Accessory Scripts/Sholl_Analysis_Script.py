#@LogService log

from ij import IJ
from ij.measure import Calibration
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

    nStatsSemiLog = NormalizedProfileStats(profile, ShollStats.AREA, 128)
    nStatsLogLog = NormalizedProfileStats(profile, ShollStats.AREA, 256)

    cal = Calibration(imp)

    maskMetrics = {'Primary Branches': lStats.getPrimaryBranches(False),
        'Intersecting Radii': lStats.getIntersectingRadii(False),
        'Sum of Intersections': lStats.getSum(False),
        'Mean of Intersections': lStats.getMean(False),
        'Median of Intersections': lStats.getMedian(False),
        'Skewness (sampled)': lStats.getSkewness(False),
        'Skewness (fit)': lStats.getSkewness(True) if bestDegree2 != -1 else 'NaN',
        'Kurtosis (sampled)': lStats.getKurtosis(False),
        'Kurtosis (fit)': lStats.getKurtosis(True) if bestDegree2 != -1 else 'NaN',
        'Maximum Number of Intersections': lStats.getMax(False),
        'Max Intersection Radius': lStats.getIndexOfInters(False, float(lStats.getMax(False))),
        'Ramification Index (sampled)': lStats.getRamificationIndex(False),
        'Ramification Index (fit)': lStats.getRamificationIndex(True) if bestDegree2 != -1 else 'NaN',
        'Centroid Radius': lStats.getCentroid(False).rawX(cal),
        'Centroid Value': lStats.getCentroid(False).rawY(cal),
        'Enclosing Radius': lStats.getEnclosingRadius(False),
        'Critical Radius': lStats.getPolynomialMaxima(0.0, 1.0, 0.5).rawX(cal) if bestDegree2 != -1 else 'Nan',
        'Mean Value': lStats.getMean(True) if bestDegree2 != -1 else 'NaN',
        'Polynomial Degree': bestDegree2 if bestDegree2 != -1 else 'Nan',
        'Regression Coefficient (semi-log)': nStatsSemiLog.getSlope(),
        'Regression Coefficient (Log-log)': nStatsLogLog.getSlope(),
        'Regression Intercept (semi-log)': nStatsSemiLog.getIntercept(),
        'Regression Intercept (Log-log)': nStatsLogLog.getIntercept()
        }

    nStatsSemiLog.restrictRegToPercentile(10, 90)
    nStatsLogLog.restrictRegToPercentile(10, 90)

    maskPercMetrics = {'Regression Coefficient (semi-log)[P10-P90]': nStatsSemiLog.getSlope(),
        'Regression Coefficient (Log-log)[P10-P90]': nStatsLogLog.getSlope(),
        'Regression Intercept (Semi-log)[P10-P90]': nStatsSemiLog.getIntercept(),
        'Regression Intercept (Log-log)[P10-P90]': nStatsLogLog.getIntercept()
        }

    maskMetrics.update(maskPercMetrics)

    csv_filename = os.path.join(str('/Users/devin.clarke/Desktop/'), 'csv_filename.csv')
    with open(csv_filename, 'wb') as f:
        writer = csv.writer(f)
        writer.writerow(list(maskMetrics.keys()))
        writer.writerow(list(maskMetrics.values()))
    

# For this demo we are going to use the ddaC sample image
args = getArgument()
#d = dict(x.split("=") for x in args.split(","))
d = [x.split("=") for x in args.split(",")]
arg_dict = dict(d)
startRad = float(arg_dict[arg_dict.keys()[0]])
stepSize = float(arg_dict[arg_dict.keys()[1]])

imp = IJ.getImage()
main(imp, startRad, stepSize)