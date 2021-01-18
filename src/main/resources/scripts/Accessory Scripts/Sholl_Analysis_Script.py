#@LogService log

'''
Based on https://github.com/morphonets/SNT/blob/master/src/main/resources/script_templates/Neuroanatomy/Analysis/Sholl_Extensive_Stats_Demo.groovy
and https://github.com/morphonets/SNT/blob/master/src/main/resources/script_templates/Neuroanatomy/Analysis/Sholl_Extract_Profile_From_Image_Demo.py
and https://gist.github.com/GenevieveBuckley/d9a7238b47d501063a3ddd782067b151 (for writing to csv)

API for LinearProfileStats = https://javadoc.scijava.org/Fiji/sc/fiji/snt/analysis/sholl/math/LinearProfileStats.html#getKStestOfFit--
for Normalised stats = https://javadoc.scijava.org/Fiji/index.html?sc/fiji/snt/package-summary.html
'''

from ij import IJ
from ij.measure import Calibration
from sc.fiji.snt import Tree
from sc.fiji.snt.analysis.sholl import (Profile, ShollUtils)
from sc.fiji.snt.analysis.sholl.gui import ShollPlot
from sc.fiji.snt.analysis.sholl.math import LinearProfileStats
from sc.fiji.snt.analysis.sholl.math import NormalizedProfileStats
from sc.fiji.snt.analysis.sholl.math import ShollStats
from sc.fiji.snt.analysis.sholl.parsers import (ImageParser2D, ImageParser3D)
import os
import csv

def main(imp, startRad, stepSize, saveLoc, maskName, cellName, tcsVal):

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
    maskImage = parser.getMask()
    maskLoc = saveLoc + "Sholl Mask " + cellName + ".tif"
    IJ.save(maskImage, maskLoc)

    # Now we can access the Sholl profile:
    profile = parser.getProfile()
    if profile.isEmpty():
        log.error("All intersection counts were zero! Invalid threshold range!?")
        return

    # Remove zeros here as otherwise this messes with polynomial fitting functions
    profile.trimZeroCounts()

    # Calculate the best fit polynomial
    lStats = LinearProfileStats(profile)

    #plot = ShollPlot(lStats)
    #plot.show()

    # Fit out polynomial
    #plot.rebuild()

    # Calculate stats from our area normalised semi-log and log-log profiles (128 is semi-log and 256 is log-log)
    nStatsSemiLog = NormalizedProfileStats(profile, ShollStats.AREA, 128)
    nStatsLogLog = NormalizedProfileStats(profile, ShollStats.AREA, 256)

    if NormalizedProfileStats(profile, ShollStats.AREA).getMethodFlag('Semi-log') != 128:
        print(str(NormalizedProfileStats(profile, ShollStats.AREA).getMethodFlag('Semi-log')))
        print('Problem with method flag for Semi-log')
        return

    if NormalizedProfileStats(profile, ShollStats.AREA).getMethodFlag('Log-log') != 256:
        print(str(NormalizedProfileStats(profile, ShollStats.AREA).getMethodFlag('Log-log')))
        print('Problem with method flag for Log-log')
        return


    # Get our image calibration and use it to extract the critical values and radii
    cal = Calibration(imp)

    # Store all our metrics in a dictionary
    maskMetrics = {'Mask Name': maskName,
        'TCS Value': tcsVal,
        'Primary Branches': lStats.getPrimaryBranches(False),
        'Intersecting Radii': lStats.getIntersectingRadii(False),
        'Sum of Intersections': lStats.getSum(False),
        'Mean of Intersections': lStats.getMean(False),
        'Median of Intersections': lStats.getMedian(False),
        'Skewness (sampled)': lStats.getSkewness(False),
        'Kurtosis (sampled)': lStats.getKurtosis(False),
        'Kurtosis (fit)': 'NaN',
        'Maximum Number of Intersections': lStats.getMax(False),
        'Max Intersection Radius': lStats.getXvalues()[lStats.getIndexOfInters(False, float(lStats.getMax(False)))],
        'Ramification Index (sampled)': lStats.getRamificationIndex(False),
        'Ramification Index (fit)': 'NaN',
        'Centroid Radius': lStats.getCentroid(False).rawX(cal),
        'Centroid Value': lStats.getCentroid(False).rawY(cal),
        'Enclosing Radius': lStats.getEnclosingRadius(False),
        'Critical Value': 'NaN',
        'Critical Radius': 'NaN',
        'Mean Value': 'NaN',
        'Polynomial Degree': 'NaN',
        'Regression Coefficient (semi-log)': nStatsSemiLog.getSlope(),
        'Regression Coefficient (Log-log)': nStatsLogLog.getSlope(),
        'Regression Intercept (semi-log)': nStatsSemiLog.getIntercept(),
        'Regression Intercept (Log-log)': nStatsLogLog.getIntercept()
        }


    # Get our P10-90 metrics
    nStatsSemiLog.restrictRegToPercentile(10, 90)
    nStatsLogLog.restrictRegToPercentile(10, 90)

    maskPercMetrics = {'Regression Coefficient (semi-log)[P10-P90]': nStatsSemiLog.getSlope(),
        'Regression Coefficient (Log-log)[P10-P90]': nStatsLogLog.getSlope(),
        'Regression Intercept (Semi-log)[P10-P90]': nStatsSemiLog.getIntercept(),
        'Regression Intercept (Log-log)[P10-P90]': nStatsLogLog.getIntercept()
        }

    maskMetrics.update(maskPercMetrics)    

    plotSL = ShollPlot(nStatsSemiLog).getImagePlus()
    plotLL = ShollPlot(nStatsLogLog).getImagePlus()

    plotSLLoc = saveLoc + "Sholl SL " + cellName + ".tif"
    plotLLLoc = saveLoc + "Sholl LL " + cellName + ".tif"

    IJ.save(plotSL, plotSLLoc)
    IJ.save(plotLL, plotLLLoc)

    # Save our file
    writeResultsLoc = saveLoc + "Sholl " + cellName + ".csv"
    with open(writeResultsLoc, 'wb') as f:
        writer = csv.writer(f)
        writer.writerow(list(maskMetrics.keys()))
        writer.writerow(list(maskMetrics.values()))

    '''
    Putting this bit about polynomial fitting down here as the following function sometimes throws an exception and this way
    we at least have some data written and placeholders NaNs if it does
    '''

    # Get the best fitting polynomial degree between 1 and 30
    bestDegree = lStats.findBestFit(1, # lowest degree
                            30,     # highest degree
                            0.7,   # lowest value for adjusted RSquared
                            0.05)   # the two-sample K-S p-value used to discard 'unsuitable fits'

    if(bestDegree != -1):
        lStats.fitPolynomial(bestDegree)
        trial = lStats.getPolynomialMaxima(0.0, 100.0, 50.0)
        critVals = list()
        critRadii = list()
        for curr in trial.toArray():
            critVals.append(curr.rawY(cal))
            critRadii.append(curr.rawX(cal))

    plotFit = ShollPlot(lStats).getImagePlus()

    plotFitLoc = saveLoc + "Sholl Fit " + cellName + ".tif"

    IJ.save(plotFit, plotFitLoc)

    maskMetrics['Kurtosis (fit)'] =  lStats.getKurtosis(True) if bestDegree != -1 else 'NaN'
    maskMetrics['Ramification Index (fit)'] = lStats.getRamificationIndex(True) if bestDegree != -1 else 'NaN'
    maskMetrics['Critical Value'] =  sum(critVals) / len(critVals)  if bestDegree != -1 else 'Nan'
    maskMetrics['Critical Radius'] =  sum(critRadii) / len(critRadii)  if bestDegree != -1 else 'Nan'
    maskMetrics['Mean Value'] =  lStats.getMean(True) if bestDegree != -1 else 'NaN'
    maskMetrics['Polynomial Degree'] =  bestDegree if bestDegree != -1 else 'Nan'

    # Save our file
    with open(writeResultsLoc, 'wb') as f:
        writer = csv.writer(f)
        writer.writerow(list(maskMetrics.keys()))
        writer.writerow(list(maskMetrics.values()))
    

# For this demo we are going to use the ddaC sample image
args = getArgument()
arg_dict = dict([x.split("=") for x in args.split(",")])
startRad = float(arg_dict['startRad'])
stepSize = float(arg_dict['stepSize'])
saveLoc = str(arg_dict['saveLoc'])
maskName = str(arg_dict['maskName'])
tcsVal = str(arg_dict['tcsVal'])

cellName = os.path.splitext(maskName)[0]

imp = IJ.getImage()
main(imp, startRad, stepSize, saveLoc, maskName, cellName, tcsVal)