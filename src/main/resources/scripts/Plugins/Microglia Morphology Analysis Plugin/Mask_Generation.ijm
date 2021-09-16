function getWorkingAndStorageDirectories(){
	//Asks the user to point us to their working and image storage directories

    Dialog.create("Pick Directory");
    Dialog.addMessage("Choose morphology analysis working directory");
    Dialog.show();

    setOption("JFileChooser", true);
    workingDirectory = getDirectory("Choose morphology analysis working directory");

    Dialog.create("Pick Directory");
    Dialog.addMessage("Choose the image storage directory");
    Dialog.show();
    //Get the parent 2P directory i.e. where all the raw 2P images are stored
    imageStorage = getDirectory("Choose the image storage directory");
	setOption("JFileChooser", false);
	
	if(workingDirectory == imageStorage) {
		exit("Selected the same directory for 'Working' and 'Image Storage'");
	}

    //Here we create an array to store the full name of the directories we'll be 
    //working with within our morphology processing directory
    directories=newArray(workingDirectory+"Input" + File.separator, 
						workingDirectory+"Output" + File.separator, 
						workingDirectory+"Done" + File.separator,
						imageStorage);
    //[0] is input, [1] is output, [2] is done, [3] is image storage

    directoriesNames = newArray('Input', 'Output', 'Done', 'Image Storage');
    for (i = 0; i < directories.length; i++) {
		print('Directories', directoriesNames[i], ':',  directories[i]);
    }

    return directories;
}

//Function finds all files that contain "substring" in the path "directoryname" 
//"fileLocations" is an array that is passed in to fill with paths that contain substring
function listFilesAndFilesSubDirectories(directoryName, subString) {

	//Get the list of files in the directory
	listOfFiles = getFileList(directoryName);

	//an array to add onto our fileLocations array to extend it so we can keep adding to it
	arrayToConcat = newArray(1);
    fileLocations = newArray(1);

	//Loop through the files in the file list
	for (i=0; i<listOfFiles.length; i++) {

		//Create a string of the full path name
		fullPath = directoryName+listOfFiles[i];
		
		//If the file we're checking is a file and not a directory and if it  contains the substring we're 
		//interested in within its full path we check  against the absolute path of our file in lower case on both counts
		if (File.isDirectory(fullPath)==0 && indexOf(toLowerCase(listOfFiles[i]), toLowerCase(subString))>-1) {
			
			//We store the full path in the output fileLocations at the latest index 
			//(end of the array) and add an extra bit onto the Array so we can keep filling it
			fileLocations = Array.concat(fileLocations, arrayToConcat);
			currentIndex=fileLocations.length-1;
			fileLocations[currentIndex] = fullPath;

		//If the file we're checking is a directory, then we run the whole thing on that directory
		} else if (File.isDirectory(fullPath)==1) {

			//Create a new array to fill whilst we run on this directory and at the end add it onyo the fileLocations array 
			tempArray = listFilesAndFilesSubDirectories(fullPath, subString);
			fileLocations = Array.concat(fileLocations, tempArray);     
			
		}
	}

	//Create a new array that we fill with all non zero values of fileLocations
	output = Array.deleteValue(fileLocations, 0);

	//Then return the output array
	return output;
	
}

function getTableColumn(fileLoc, colName) {
	//Open the table at fileLoc, retrieve the colName column, if it doesn't exist,
	//return an array the size of the table filled with -1

	print("Retrieving the column ", colName, " from the table ", File.getName(fileLoc));

	if(File.exists(fileLoc) != 1) {
		exit("Table " + fileLoc + "doesn't exist");
	}

	open(fileLoc);
	tableName = Table.title;
	selectWindow(tableName);

	//If our column exists
	columns = Table.headings;
	if(indexOf(columns, colName) > -1) {
		outputArray = Table.getColumn(colName);
	
	//Else
	} else {
		outputArray = newArray(Table.size);
		Array.fill(outputArray, -1);
	}

	selectWindow(tableName);
	run("Close");

	return outputArray;

}

function findFileWithFormat(folder, fileFormat) {
	//Look for a file with the format fileFormat in folder

	//We get the list of files in the folder
	fileList = getFileList(folder);
	
	//Create an array to store our locations and a counter for how many files we've found
	storeIt = newArray(1);
	storeIt[0] = 'none';
	count = 0;
	for(i=0; i<fileList.length; i++) {
		if(endsWith(toLowerCase(fileList[i]), fileFormat)) {
			//Create a variable that tells us which file has the format we're looking for
			fileLocation = folder + fileList[i]; 
			
			//If we're onto our second location, create a new array to tack onto storeIt that we then
			//fill with the new location
			if(count >0) {
				appendArray = newArray(1);
				storeIt = Array.concat(storeIt, appendArray);
			}
			
			//Store the location and increase the count
			storeIt[count] = fileLocation;
			count += 1;
		}
	}

	if(storeIt[0] == 'none') {
		print("No file found");
		return newArray('Not found');
	} else {
		return storeIt;
	}

}

//This is a function to retrieve the data from the ini file. The ini file contains calibration information for the 
//entire experiment that we use to calibrate our images. iniFolder is the folder within which the ini file is located, 
//and iniValues is an array we pass into the function that we fill with calibration values before returning it	
function getIniData(iniFolder, iniStrings) {

	print("Retrieving .ini data");

	//Find our ini file
	iniLocations = findFileWithFormat(iniFolder, "ini");
	if(iniLocations.length > 1) {
		exit("More than 1 ini file found, exiting plugin");
	} else if(iniLocations[0] != 'Not found') {
		print(".ini file found at", iniLocations[0]);
		iniToOpen = iniLocations[0];
	} else if(iniLocations[0] == 'Not found') {
		exit("No ini file found for calibration");
	}

	iniValues = parseIniValues(iniStrings, iniToOpen);
		
	return iniValues;
}

function parseIniValues(iniStrings, iniToOpen) {
	//Parse our ini values from the strings in the ini file
		
	//We open the ini file as a string
	iniText = File.openAsString(iniToOpen);	
	
	iniValues = newArray(iniStrings.length);

	//Looping through the values we want to grab
	for(i=0; i<iniStrings.length; i++) {

		//We create a start point that is the index of our iniStrings + the length of the string
		startPoint = indexOf(iniText, iniStrings[i])+lengthOf(iniStrings[i]);

		//Get a substring that starts at our startPoint i.e. where the numbers of our current string start
		checkString = substring(iniText, startPoint);

		//For each character, if it isn't numeric add 1 to the hitCount and if we hit
		//two consecutive non-numerics, go back to pull out the values and store them
		hitCount = 0;
		for(j=0; j<lengthOf(checkString); j++) {
			if(charCodeAt(checkString, j) < 48 || charCodeAt(checkString, j) > 57) {
				hitCount = hitCount + 1;
				if(hitCount == 2) {
					realString = substring(checkString, 0, j);
					break;
				}
			}
		}

		//Parse our values
		iniValues[i] = parseFloat(realString);
	}

	return iniValues;

}


function substacksToUse(substackTableLoc, nameCol, processedCol, QCCol) {

	print("Retrieving the substacks that are ready for mask generation");

	//We return an array of substack names to use if they have been processed an QAs
	substackNames = getTableColumn(substackTableLoc, nameCol);
	processed = getTableColumn(substackTableLoc, processedCol);
	qaValue = getTableColumn(substackTableLoc, QCCol);

	if(substackNames[0] != -1) {

		output = newArray(1);
		added = 0;
		
		//For each substack, if its been processed and QA'd it's ready for analysis
		for(currSub = 0; currSub<substackNames.length; currSub++) {
			if(processed[currSub] == 1 && qaValue[currSub] == 1) {
				if(added == 0) {
					output[0] = substackNames[currSub];
				} else {
					output = Array.concat(output, newArray(substackNames[currSub]));
				}
				added = added + 1;
			}
		}

		//If none of the substacks are ready for analysis, return an array population with the string
		//'nothing'
		if(output[0] == 0) {
			output = newArray('nothing');
		}

	} else {
		exit("Substack names column in " + substackTableLoc + " not populated");
	}

	return output;

}

function getOrCreateTableColumn(tableLoc, columnName, defaultValue, defaultLength) {

	//If our table exists, get our column
	if(File.exists(tableLoc) == 1) {
		outputArray = getTableColumn(tableLoc, columnName);
	} else {
		print("Table doesn't exist; creating array with default value of default length");
		outputArray = newArray(defaultLength);
		Array.fill(outputArray, defaultValue);
	}

	//If it exists, make sure its the same length as default, if it's longer,
	//add that length
	if(File.exists(tableLoc) == 1 && outputArray.length < defaultLength) {
		fillWithArray = newArray(defaultLength - outputArray.length);
		Array.fill(fillWithArray, defaultValue);
		outputArray = Array.concat(outputArray, fillWithArray);
	}

	return outputArray;
}

function makeDirectories(directories) {

    //Here we make our working directories by looping through our folder names, 
    //concatenating them to our main parent directory
    //and making them if they don't already exist
    for(i=0; i<directories.length; i++) {
        if(File.exists(directories[i])==0) {
            File.makeDirectory(directories[i]);
            print('Made directory ', directories[i]);
        } else {
        	print('Directory', directories[i], 'already exists');
        }
    }
}

function getMaskGenerationInputs() {

	//These are the required inputs from the user
	strings = newArray("What mask size would you like to use as a lower limit?",
	"What mask size would you like to use as an upper limit?",
	"What range would you like to use for mask size error?",
	"What increment would you like to increase mask size by per loop?",
	"What area should the local region around each cell location be? (in um)");

	//TCS is target cell size, we iteratively threshold our cells to reach the 
	//TCS +/- the range/ The TCS lower is the minimum TCS we want to get results 
	//from, the TCS upper is the highest. Increment is how much we increase the 
	//TCS we're using each iteration to go from TCS lower to TCS upper. Trace is 
	//whether the user wants to manually trace processes to add to the analysis

	Dialog.create("Info for each section");

	defaultValues = newArray(200, 800, 100, 100, 120);

	//Here we loop through the strings and add a box for numeric input for each
	for(i=0; i<strings.length; i++) {
		Dialog.addNumber(strings[i], defaultValues[i]);
	}
			
	Dialog.show();
						
	//Retrieve user inputs and store the selections in the selection array
	selection = newArray(strings.length);
	for(i=0; i<strings.length; i++) {
		selection[i] = Dialog.getNumber();
	}

	return selection;

}

function openAndCalibrateImage(imageLocation, iniValues) {
	
	//We open the image then calibrate it
	open(imageLocation);
	avgProjImage = File.getName(imageLocation);
	selectWindow(avgProjImage);
	run("Properties...", "channels=1 slices=1 frames=1 unit=um pixel_width="+iniValues[0]+" pixel_height="+iniValues[1]+" voxel_depth="+iniValues[2]+"");
}

function coordinatesWithinBuffer(imageLocation, currXCoord, currYCoord, bufferInPixels) {
	
	//Select our image and get its dimensions
	selectWindow(File.getName(imageLocation));
	getDimensions(originalWidth, originalHeight, originalChannels, originalSlices, originalFrames);
	
	//Calculate if our y or x coordinates are more than bufferInPixels pixels away from the edges of the image
	yInsideBuffer = (currYCoord > bufferInPixels) && (currYCoord < (originalHeight - bufferInPixels));
	xInsideBuffer = (currXCoord > bufferInPixels) && (currXCoord < (originalWidth - bufferInPixels));

	//Return if both coordinates are inside our buffered area
	return (yInsideBuffer && xInsideBuffer);

}

function getLRCoords(imageLoc, cellLocCoords, LRLengthPixels) {

	//Here we store x and y values that we would use to draw a 120x120um square around our coordinate - we store the coordinates
	//that would be the top left corner of this square as that is what we need to input to draw it
	LRCoords = newArray(cellLocCoords[0]-(LRLengthPixels/2), cellLocCoords[1]-(LRLengthPixels/2));

	//Get our image dimensions
	selectWindow(File.getName(imageLoc));
	getDimensions(LRWidth, LRHeight, LRChannels, LRSlices, LRFrames);

	//For each of our cell coordinates
	for(currCoord = 0; currCoord < cellLocCoords.length; currCoord++) {

		//If that coordinate is too close to the left or bottom of the image for us to create a
		//local region with the existing LR coordinates
		if(cellLocCoords[currCoord] < LRLengthPixels/2) {

			//Set our LR coord to 0 (else it would be -ve)
			LRCoords[currCoord] = 0;

		}
	}

	//If the coordinate is too close to the right of the image for us to draw a full LR
	if((LRWidth - cellLocCoords[0]) < LRLengthPixels/2) {
		//Set the LR coordinate to be at least one LR length away from the right
		LRCoords[0] = LRWidth - LRLengthPixels;
	}

	//Can't be too close to the top since it's the top left...
	/*
	//If the coordinate is too close to the top of the image for us to draw a full LR
	if((LRHeight - cellLocCoords[1]) < LRLengthPixels/2) {
		//Set the LR coordinate to be at least one LR length away from the top
		LRCoords[1] = LRHeight - LRLengthPixels;
	}
	*/

	//If our coordinates end up being outside our image (i.e. the image isnt big enough to create a
	//local region of our specified size) set them to 0
	if(LRCoords[0] < 0) {
		LRCoords[0] = 0;
	}

	if(LRCoords[1] < 0) {
		LRCoords[1] = 0;
	}

	//Return our adjusted coordinates for drawing our local region
	return LRCoords;


}

function createLRImage(imageLoc, LRCoords, LRLengthArray) {

	//Select our image and clear any selections
	imageTitle = File.getName(imageLoc);
		
	selectWindow(imageTitle);
	run("Select None");

	//Here we make our local region based on all the values we've calculated
	makeRectangle(LRCoords[0], LRCoords[1], LRLengthArray[0], LRLengthArray[1]);
	run("Duplicate...", " ");

	//Rename our duplicated image as LR
	rename("LR");
	run("Select None");


}

function returnMaxAtPoint(xPoint, yPoint, windowName) {
	selectWindow(windowName);
	run("Select None");
	topValue = getPixel(xPoint, yPoint)-1;

	return topValue;
}

function getOtsuValue(imageLoc, xCoord, yCoord) {

	//Select our LR image, auto threshold it using Otsu, and get the threshold values
	print("Getting starting otsu thresholding value");
	selectWindow("LR");
	setAutoThreshold("Otsu dark");
	selectWindow("LR");
	getThreshold(otsu, upper);

	//Get the grey value at the marked cell coordinate, if the otsu threshold value is above the value
	//at the marked point, adjust the threshold value so it is at least as high as the point marked
	selectWindow(File.getName(imageLoc));
	pointValue = returnMaxAtPoint(xCoord, yCoord, File.getName(imageLoc));
	pointValue = pointValue - 1;
	otsu = valueCheck(otsu, pointValue);

	//Return our threshold value
	return otsu;

}

//Function to check if the inputValue is above the topLimit - this is so that if 
//our thresholding calculated value ends up above the highest grey value in the 
//image then we set inputValue to that top value
function valueCheck(inputValue, topLimit) {
	
	if(inputValue>=topLimit) {
		print("Value is above our limit, setting to our limit - 1");
		inputValue = topLimit-1;
	} else {
		print("Value is within our limits");
	}

	//We want a rounded threshold value since the images are in 8-bit, so we do 
	//that before returning it
	return round(inputValue);
}

function getConnectedMask(xCoord, yCoord, thresholdVal) {

	//Select our LR image, make the point at the coordinates specified, then find the connected regions to that point that are equal or above
	//the threhsold value in grey intensity
	print("Finding mask connected to our coordinates ", xCoord, yCoord, " at our threshold ", thresholdVal);
	selectWindow("LR");
	setBackgroundColor(0,0,0);
	selectWindow("LR");
	makePoint(xCoord, yCoord);

	run("Find Connected Regions", "allow_diagonal display_image_for_each start_from_point regions_for_values_over="+thresholdVal+" minimum_number_of_points=1 stop_after=1");
	imgNamemask=getTitle();

	//Rename the connected pixels mask as 'Connected'
	rename("Connected");
	print("Connected pixels found");

}

function findMaximaInCoords() {

	//For our connected mask image, get the selection that defines it
	print("Finding the local maxima in our Connected image");
	selectWindow("Connected");
    setThreshold(1, 255);
	run("Create Selection");
	getSelectionCoordinates(xpoints, ypoints);

	//Apply this selection to a duplicate of our LR image	
	selectWindow("LR");
	run("Duplicate...", " ");
	selectWindow("LR-1");
	makeSelection("freehand", xpoints, ypoints);
	run("Clear Outside");
	List.setMeasurements;

	//Here we get the max value in that image and get out the coordinates of it using the
	//"find maxima" function			
	topValue = List.getValue("Max");
	run("Select None");
	run("Find Maxima...", "noise=1000 output=[Point Selection]");
	getSelectionCoordinates(tempX, tempY);
	adjustedCellCoords = newArray(tempX[0], tempY[0]);
	selectWindow("LR-1");
	run("Close");
	selectWindow("Connected");
	run("Close");

	return adjustedCellCoords;

}

function saveImage(Image, saveLoc) {

	//Now that we're certain we've got the optimal coordinates, we save our LR image
	selectWindow(Image);
	run("Select None");
	saveAs("tiff", saveLoc);
	selectWindow(File.getName(saveLoc));
	rename(Image);

}

function getCurrentMaskArea(xCoord, yCoord, threshold) {

	print("Getting area associated with our current mask");

	//Here we are finding the  connected region at our point using our threshold and then computing the area of the 
	//connected mask
	getConnectedMask(xCoord, yCoord, threshold);

	selectWindow("Connected");
    setThreshold(1, 255);
	run("Create Selection");
	getStatistics(area);

	return area;


}

function getArrayOfMatchingValues(lookInArray, lookForValue, getValueFromArray) {

	matchingValues = newArray(lookInArray.length);
	Array.fill(matchingValues, -1);

	//For every element in our reference array
	for(currElement=0; currElement<lookInArray.length; currElement++) {
		
		//If the element matches what we're trying to find
		if(lookInArray[currElement] == lookForValue) {

			//Store what our matching value is
			matchingValues[currElement] = getValueFromArray[currElement];
		}

	}

	//Delete all filler values in our matchingY array
	cleanVals = Array.deleteValue(matchingValues, -1);

	return cleanVals;

}

function getRoundedMeanOfArray(array) {

	//Get and return the mean of our matching values
	Array.getStatistics(array, min, max, mean, sd);

	return round(mean);

}

function tooCloseToEdge(imageName, bufferSize) {

	//For our image, get a selection that defines it
	print("Calculating if our selection is too close to the edge of our image");
	selectWindow(imageName);
    setThreshold(1, 255);
	run("Create Selection");
	getSelectionCoordinates(xCoords, yCoords);
	Array.getStatistics(xCoords, xMin, xMax, xMean, stdDev);
	Array.getStatistics(yCoords, yMin, yMax, yMean, stdDev) ;

	//For our rightmost point, we already have our definixing X value (xMax) but we need to find the y value
	//at the xMax coordinate, so get the mean of any matching y points
	rightmostYArray = getArrayOfMatchingValues(xCoords, xMax, yCoords);
	rightmostY = getRoundedMeanOfArray(rightmostYArray);

	//For leftmost we already have our defining x (xMin) so again, get the mean of matching y points
	leftmostYArray = getArrayOfMatchingValues(xCoords, xMin, yCoords);
	leftmostY = getRoundedMeanOfArray(leftmostYArray);

	//etc.
	topmostXArray = getArrayOfMatchingValues(yCoords, yMin, xCoords);
	topmostX = getRoundedMeanOfArray(topmostXArray);

	bottommostXArray = getArrayOfMatchingValues(yCoords, yMax, xCoords);
	bottommostX = getRoundedMeanOfArray(bottommostXArray);

	xPoints = newArray(xMax, xMin, bottommostX, topmostX);
	yPoints = newArray(rightmostY, leftmostY, yMax, yMin);
	//[0] and [1] are highest x with y (rightmost), [2] and [3] are lowest x with y (leftmost), 
	//[4] and [5] are x and highest y (bottommost) [6] and [7] are x with lowest y (topmost)

	print(xPoints[0], yPoints[0]);
	print(xPoints[1], yPoints[1]);
	print(xPoints[2], yPoints[2]);
	print(xPoints[3], yPoints[3]);

	print(imageName);

	//For our 4 extrema, find out if they're within the buffer of our image
	inBufferResults = newArray(xPoints.length);
	for(currPoint = 0; currPoint < 4; currPoint++) {
		inBufferResults[currPoint] = coordinatesWithinBuffer(imageName, xPoints[currPoint], yPoints[currPoint], bufferSize);
		print(inBufferResults[currPoint]);
	}

	//If the mean of our results is 1 then all our results were true and we return false since we're not
	//too close to the edge, else we return true
	Array.getStatistics(inBufferResults, min, max, mean, stdDev);

	print(mean);

	if(mean == 1) {
		return false;
	} else {
		return true;
	}

}

function getMaskStatus(area, currentTCS, TCSRange, touching, stabilised) {

	print("Calculating if we should proceed with iterative thresholding for mask generation");

	//limits is an array to store the lower and upper limits of the cell area we're using within this TCS loop, calculated
	//according to the error the user input
	limits = newArray(currentTCS-TCSRange, currentTCS+TCSRange);
	
	nextIteration = 0;

	//If the area of the mask is below the target mask size + range
	if (area<limits[0]) {

		print("Selection area is below our lower TCS limit");

		//If the mask touches the edges, reject it - the mask can only get bigger with further iterations
		//so this can not be resolved
		if(touching == true) {
			nextIteration = -1;

		//If we're not touching the edges
		} else {

			//If the mask size has stabilised to this value, accept it
			if(stabilised == true) {
				nextIteration = 0;
			
			//If the mask size has yet to stabilise, keep iterating
			} else  {
				nextIteration = 1;
			}
		}
	
	//If its within our limits, we check if its touching edges, and if it isn't touching any edges we save it, else we keep going
	} else if (area<=limits[1] && area>=limits[0]) {

		print("Selection area is within our TCS limits");

		//If the mask is within our limits but touches the edges
		if(touching == true) {

			//if the mask hasn't stabilised, keep iterating in the hopes it resolves
			if(stabilised == false) {
				nextIteration = 1;

			//If the mask is touching and has stabilised here, reject it
			} else {
				nextIteration = -1;
			}
		
		//If the mask isn't touching the edges
		} else {

			//If it's stabilised, retain it
			if(stabilised == true) {
				nextIteration = 0;

			//If it hasn't retain it
			} else {
				nextIteration = 0;
			}
		}

	//If we're above the limits
	} else if (area>limits[1]) {

		print("Selection area is above our upper TCS limit");

		//If we're touching the edges
		if(touching == true) {

			//If we've stabilised, reject it
			if(stabilised == true) {
				nextIteration = -1;
			
			//If we've not stabilised, keep iterating in the hope we resolve
			} else {
				nextIteration = 1;
			}

		//If we're not touching
		} else  {

			//If we've stabilised, retain the mask
			if(stabilised == true) {
				nextIteration = 0;

			//If we've not stabilised, keep iterating 
			} else  {
				nextIteration = 1;
			}
		}

	}

	return nextIteration;

}

//Function to calculate the next threshold to use for iterative thresholding
function calculateNextThreshold(t1, a1, ms, n) {
	//T1 is the current threshold
	//A1 is the current mask area
	//MS is the target mask size
	//N is the number of iterations thus far

	firstClause = t1;
	secondClause = t1 * ((a1 - ms) / (n * ms));

	nextThresholdRaw = firstClause + secondClause;

	return nextThresholdRaw;

}

function saveMaskGenerationTable(maskName, maskTry, maskSuccess, maskQA, maskQuant, saveLoc) {
	//Save these arrays into a table
	Table.create("Mask Generation.csv");
	selectWindow("Mask Generation.csv");
	Table.setColumn("Mask Name", maskName);
	Table.setColumn("Mask Try", maskTry);
	Table.setColumn("Mask Success", maskSuccess);
	Table.setColumn("Mask QA", maskQA);
	Table.setColumn("Mask Quantified", maskQuant);
	Table.save(saveLoc);
	selectWindow("Mask Generation.csv");
	run("Close");
}

function saveTCSStatusTable(currentSubstack, tcsValue, tcsMasksGenerated, tcsQCChecked, tcsAnalysed, saveLoc) {
	//Save these arrays into a table
	Table.create("TCS Status Substack(" + currentSubstack +").csv");
	selectWindow("TCS Status Substack(" + currentSubstack +").csv");
	Table.setColumn("TCS", tcsValue);
	Table.setColumn("Masks Generated", tcsMasksGenerated);
	Table.setColumn("QC Checked", tcsQCChecked);
	Table.setColumn("Analysed", tcsAnalysed);
	Table.save(saveLoc);
	selectWindow("TCS Status Substack(" + currentSubstack +").csv");
	run("Close");
}

function saveSubstackCoordinatesLocTable(xCoords, yCoords, xOpt, yOpt, optimalThreshold, saveLoc) {

	print("Updating and saving our ", File.getName(saveLoc), " table");

	//Save these arrays into a table
	Table.create(File.getName(saveLoc));
	selectWindow(File.getName(saveLoc));
	Table.setColumn("X", xCoords);
	Table.setColumn("Y", yCoords);
	Table.setColumn("xOpt", xOpt);
	Table.setColumn("yOpt", yOpt);
	Table.setColumn("Optimal Threshold", optimalThreshold);
	Table.save(saveLoc);
	selectWindow(File.getName(saveLoc));
	run("Close");

}

function makeOrRetrieveLR(lrSaveLoc, LRCoords, LRLengthPixels, avgProjImageLoc) {

	//If we already have made a LR image, retrieve it
	if(File.exists(lrSaveLoc) == 1) {

		print("Loading in already created local region image");
		
		open(lrSaveLoc);
		selectWindow(File.getName(lrSaveLoc));
		rename("LR");

	//Else make it and save it
	} else {

		print("Making local region image");	

		//Issues with this
		createLRImage(avgProjImageLoc, LRCoords, newArray(LRLengthPixels, LRLengthPixels));

		//Now that we're certain we've got the optimal coordinates, we save our LR image
		saveImage("LR", lrSaveLoc);

	}

}

function findOrRetrieveOptimalCoordinates(avgProjImageLoc, LRCoords, xCoords, yCoords, xOpt, yOpt, optimalThreshold, currCell, substackCoordinatesLoc) {

	//If we don't have any optimised cell coordinates yet for this cell, find them
	if(xOpt[currCell] == -1) {

		print("Generating optimal coordinates for mask generation");

		//Get the otsu value of our local region
		initialThreshold = getOtsuValue(avgProjImageLoc, xCoords[currCell], yCoords[currCell]);

		print("Initial threshold value of " + initialThreshold);

		lrXCoord = floor(xCoords[currCell] - LRCoords[0]);
		lrYCoord = floor(yCoords[currCell] - LRCoords[1]);

		//Get the value of the maxima
		adjInitial = returnMaxAtPoint(lrXCoord, lrYCoord, "LR");

		//Get a connected mask centered on the centre of the local region - as this is centered on our chosen cell coordinate
		getConnectedMask(lrXCoord, lrYCoord, adjInitial);

		//Get the coordinates of the maxima in the local region
		maximaCoordinates = findMaximaInCoords();
		xOpt[currCell] = floor(maximaCoordinates[0]);
		yOpt[currCell] = floor(maximaCoordinates[1]);

		//Get the value of the maxima
		topValue = returnMaxAtPoint(xOpt[currCell], yOpt[currCell], "LR");

		//Check if our initial threshold is above our maxima, and  if so adjust it
		optimalThreshold[currCell] = valueCheck(initialThreshold, topValue);

		//Store our optimal coordinates, our threshold, and our maxima value, in an output array
		lrCoordinateValues = newArray(xOpt[currCell], yOpt[currCell], optimalThreshold[currCell], topValue);

		//Save our substack coordinates loc table with the new values
		saveSubstackCoordinatesLocTable(xCoords, yCoords, xOpt, yOpt, optimalThreshold, substackCoordinatesLoc);
	
	//Else, retrieve them
	} else {

		print("Using existing optimal coordinates for mask generation");

		//Get the value at our optimal coordinates
		topValue = returnMaxAtPoint(xOpt[currCell], yOpt[currCell], "LR");

		//Store everything in the output array
		lrCoordinateValues = newArray(xOpt[currCell], yOpt[currCell], optimalThreshold[currCell], topValue);
	}

	return lrCoordinateValues;

}

function getSubstacksToUse(directories, imageNameRaw) {
	
	//Read in our substacks table
	statusTable = directories[1]+imageNameRaw+"/Cell Coordinate Masks/Cell Position Marking.csv";
	if(File.exists(statusTable) != 1) {
		substackNames = newArray('nothing');
		print("Run cell detection for this image first");
		print('Skipping this image');
	} else {

		//Get out an array of substacks to iterate through
		substackNames = substacksToUse(statusTable, 'Substack', 'Processed', 'QC');

	}
	
	return substackNames;
}

function populateTCSValueArray(tcsValue, numberOfLoops, selection) {

	//Populate our array with TCS values
	for(TCSLoops=0; TCSLoops<numberOfLoops; TCSLoops++) {
		tcsValue[TCSLoops] = selection[0]+(selection[3]*TCSLoops);
	}

	return tcsValue;

}

function iterativeThresholding(nextIteration, initialThreshold, firstArea, tcsValue, TCSLoops, topValue, lrCoordinateValues) {

	//These variables are changed depending on how many iterations a mask has stabilised for (regardless of whether it fits
	// the TCS +/- the range, as if it stabilized 3 times we keep it), and loopcount ticks up each iteration we go through
	//as we use this value to change the otsu we use for the subsequent iteration 
	stabilisedCount = 0;
	loopCount = 0;

	//Here if we are proceeding with the iterative thresholding
	while (nextIteration==1) {

		print("Mask doesn't meet stopping requirements, continuing to iterate");

		selectWindow("Connected");
		run("Close");

		loopCount++; //Each iteration we increase loopCount, this modifies how we alter the threshold value

		//This variable stores the next threshold value we'll use based on a formula outlined later
		//If we're on our first iteration, use the initial threshold and firstArea inputs
		//Else use the previously calculated iterative values
		if(loopCount == 1) {
			t1 = initialThreshold;
			a1 = firstArea;
		} else {
			t1 = nextThreshold;
			a1 = areaNew;
		}

		ms = tcsValue[TCSLoops];
		n = loopCount;
		
		print("Calculating next threshold value to use");

		nextThresholdRaw = calculateNextThreshold(t1, a1, ms, n);

		print("Next thresholdRaw is ", nextThresholdRaw);

		//print("nextThresh: ", otsuVariables[1]);
		//print("otsuNorm: ", otsu/255);
		//print("area: ", area);
		//print("TCS: ", currentLoopValues[0]);
		//print("Loop count: ", maskGenerationVariables[1]);
				
		//Check if our next threshold is higher than the maximum pixel value in the image - if so, set to
		//maximal pixel value
		nextThreshold = valueCheck(nextThresholdRaw, topValue);

		//Here we get the area from our find connected regions
		//print("otsu to check: ", otsuVariables[1]);
		//print("bottom value: ", bottomValue);
		//print("top value: ", topValue);
		print("Threshold value of " + nextThreshold);
		areaNew = getCurrentMaskArea(lrCoordinateValues[0], lrCoordinateValues[1], nextThreshold);

		print("Mask area is = "+areaNew+"um^2");
		print("Previous area was ", a1);
		
		//If we get the same area for 3 iterations we exit the iterative process, so here we count identical areas 
		//(but if for any one instance they are not identical, we reset the counter)
		if (areaNew==a1){
			print("Areas are the same");
			stabilisedCount++;
			print(stabilisedCount);
		} else {
			print("Areas are not the same");
			stabilisedCount=0;	
		}

		if(stabilisedCount == 3) {
			stabilised = true;
			print("Mask area has stabilised");
		}

		//Here, as before, we look at which condition the mask falls into and act appropriately to either continue iterating, 
		//save the mask, or discard the mask
		touching = tooCloseToEdge("Connected", fiveMicronsInPixels);
		nextIteration = getMaskStatus(areaNew, tcsValue[TCSLoops], selection[2], touching, stabilised);

	} //Once the output of threshContinue==false, then we exit the process

	return nextIteration;

}

function createTCSArrays(numberOfLoops, selection) {

	//Populate an array with all the TCS values we want to create masks for
	tcsValueRaw = populateTCSValueArray(newArray(numberOfLoops), numberOfLoops, selection);

	//Create the other arrays we need to store info about these with
	tcsMasksGeneratedRaw = newArray(numberOfLoops);
	tcsQCCheckedRaw = newArray(numberOfLoops);
	tcsAnalysedRaw = newArray(numberOfLoops);

	tcsMasksGenerated = Array.fill(tcsMasksGeneratedRaw, -1);
	tcsQCChecked = Array.fill(tcsQCCheckedRaw, -1);
	tcsAnalysed = Array.fill(tcsAnalysedRaw, -1);

	
	//Return them as one big array
	return Array.concat(tcsValueRaw, tcsMasksGenerated, tcsQCChecked, tcsAnalysed);

}

function fillTCSArraysWithExisting(tcsStatusTable, numberOfLoops, tcsArrays) {

	//Get our old TCS arrays and info if they exist
	tcsValueOld = getOrCreateTableColumn(tcsStatusTable, "TCS", -1, numberOfLoops);
	tcsMasksGeneratedOld = getOrCreateTableColumn(tcsStatusTable, "Masks Generated", -1, numberOfLoops);
	tcsQCCheckedOld = getOrCreateTableColumn(tcsStatusTable, "QC Checked", -1, numberOfLoops);
	tcsAnalysedOld = getOrCreateTableColumn(tcsStatusTable, "Analysed", -1, numberOfLoops);

	//Slice up our new arrays into the corresponding parts
	tcsValueNew = Array.slice(tcsArrays, 0, numberOfLoops);
	tcsMasksGeneratedNew = Array.slice(tcsArrays, numberOfLoops, numberOfLoops*2);
	tcsQCCheckedNew = Array.slice(tcsArrays, (numberOfLoops*2), numberOfLoops*3);
	tcsAnalysedNew = Array.slice(tcsArrays, (numberOfLoops*3), numberOfLoops*4);

	//If we find a matching TCS value in the old, populate the values in the new
	//with them
	for(oldTCS = 0; oldTCS < tcsValueOld.length; oldTCS++) {
		for(newTCS = 0; newTCS < tcsValueNew.length; newTCS++) {
			if(tcsValueOld[oldTCS] == tcsValueNew[newTCS]) {
				tcsMasksGeneratedNew[newTCS] = tcsMasksGeneratedOld[oldTCS];
				tcsQCCheckedNew[newTCS] = tcsQCCheckedOld[oldTCS];
				tcsAnalysedNew[newTCS] = tcsAnalysedOld[oldTCS];
			}
		}
	}
	
	//Return these filled arrays as one big array
	return Array.concat(tcsValueNew, tcsMasksGeneratedNew, tcsQCCheckedNew, tcsAnalysedNew);

}

function identifyMissingTCSIndices(tcsValueOld, tcsValueNew) {

	//For each old TCS
	nonMatchCount = 0;
	nonMatching = newArray(1);
	nonMatching[0] = -1;
	for(oldTCS = 0; oldTCS < tcsValueOld.length; oldTCS++) {
		match = false;

		//Check if it is found in the new tcs values
		for(newTCS = 0; newTCS < tcsValueNew.length; newTCS++) {
			if(tcsValueOld[oldTCS] == tcsValueNew[newTCS]) {
				match = true;
			}
		}

		//If not, store its index in an array
		if(match == false && tcsValueOld[oldTCS] != -1) {
			if(nonMatchCount == 0) {
				nonMatching = newArray(1);
				nonMatching[0] = oldTCS;
			} else {
				nonMatching = Array.concat(nonMatching, oldTCS);
			}
			nonMatchCount++;
		}
	}

	//Return this array
	return nonMatching;

}

function fillWithMissingTCSValues(nonMatchingIndices, tcsStatusTable, tcsArrays, numberOfLoops) {

	//Get all our old TCS info
	tcsValueOld = getOrCreateTableColumn(tcsStatusTable, "TCS", -1, numberOfLoops);
	tcsMasksGeneratedOld = getOrCreateTableColumn(tcsStatusTable, "Masks Generated", -1, numberOfLoops);
	tcsQCCheckedOld = getOrCreateTableColumn(tcsStatusTable, "QC Checked", -1, numberOfLoops);
	tcsAnalysedOld = getOrCreateTableColumn(tcsStatusTable, "Analysed", -1, numberOfLoops);

	//Cut up our new TCS info (filled in with matching old)
	tcsValueNew = Array.slice(tcsArrays, 0, numberOfLoops);
	tcsMasksGeneratedNew = Array.slice(tcsArrays, numberOfLoops, numberOfLoops*2);
	tcsQCCheckedNew = Array.slice(tcsArrays, (numberOfLoops*2), numberOfLoops*3);
	tcsAnalysedNew = Array.slice(tcsArrays, (numberOfLoops*3), numberOfLoops*4);

	//Create some new arrays we will use to store the non matching old
	tcsValAdd = newArray(nonMatchingIndices.length);
	tcsMasksGeneratedAdd = newArray(nonMatchingIndices.length);
	tcsQCCheckedAdd = newArray(nonMatchingIndices.length);
	tcsAnalysedAdd = newArray(nonMatchingIndices.length);

	//For each non matching old, fill the arrays with the info
	for(nonMatch = 0; nonMatch < nonMatchingIndices.length; nonMatch++) {
		index = nonMatchingIndices[nonMatch];
		tcsValAdd[nonMatch] = tcsValueOld[index];
		tcsMasksGeneratedAdd[nonMatch] = tcsMasksGeneratedOld[index];
		tcsQCCheckedAdd[nonMatch] = tcsQCCheckedOld[index];
		tcsAnalysedAdd[nonMatch] = tcsAnalysedOld[index];
	}

	//Concat these non matching arrays with the new TCS arrays so we have records of all old TCS
	//whether they're included in the new or not
	tcsValue = Array.concat(tcsValueNew, tcsValAdd);
	tcsMasksGenerated = Array.concat(tcsMasksGeneratedNew, tcsMasksGeneratedAdd);
	tcsQCChecked = Array.concat(tcsQCCheckedNew, tcsQCCheckedAdd);
	tcsAnalysed = Array.concat(tcsAnalysedNew, tcsAnalysedAdd);
	
	//Format the length of our arrays as something we can pass in a concatenated array
	toPassArray = newArray('0');
	toPass = tcsValueNew.length;
	toPassArray[0] = toPass;

	//Return the length of these new arrays, and then these new arrays
	return Array.concat(toPassArray, tcsValue, tcsMasksGenerated, tcsQCChecked, tcsAnalysed);

}

setBatchMode(true);

//Get user input into where our working directory, and image storage directories, reside
directories = getWorkingAndStorageDirectories();
//[0] is input, [1] is output, [2] is done (working directories) [3] is directoryName (storage directory)

selection = getMaskGenerationInputs();
//"What mask size would you like to use as a lower limit?",
//"What mask size would you like to use as an upper limit?",
//"What range would you like to use for mask size error?",
//"What increment would you like to increase mask size by per loop?",
//"What area should the local region around each cell location be? (in um)");

//Set the size of the square to be drawn around each cell in um
LRSize = selection[4];

//Here we calculate how many loops we need to run to cover all the TCS values 
//the user wants to use
numberOfLoops = ((selection[1]-selection[0])/selection[3])+1;

//Populate our image info arrays
imagesToUseFile = directories[1] + "Images to Use.csv";

if(File.exists(imagesToUseFile) != 1) {
	exit("Need to run the stack preprocessing and stack QA steps first");
}

//If we already have a table get out our existing status indicators
imageName = getTableColumn(imagesToUseFile, "Image Name");

//This is an array with the strings that come just before the information we want to retrieve from the ini file.
iniTextStringsPre = newArray("x.pixel.sz = ", "y.pixel.sz = ", "z.spacing = ", "no.of.planes = ", "frames.per.plane = ");

//Array to store the values we need to calibrate our image with
iniValues =  getIniData(directories[3], iniTextStringsPre);
//Index 0 is xPxlSz, then yPxlSz, zPxlSz, ZperT, FperZ

////////////////////////////////////Automatic Microglial Segmentation///////////////////////////////////////////////////////////

//This is the main body of iterative thresholding, we open processed input images and use the coordinates of the cell locations previuosly 
//input to determine cell locations and create cell masks
for (currImage=0; currImage<imageName.length; currImage++) {
	
	print("Processing image ",File.getNameWithoutExtension(imageName[currImage]));

	imageNameRaw = File.getNameWithoutExtension(imageName[currImage]);

	LRDir = directories[1] + imageNameRaw + "/" + "Local Regions/";
	makeDirectories(newArray(LRDir));

	substackNames = getSubstacksToUse(directories, imageNameRaw);

	if(substackNames[0] != 'nothing'){

		//Loop through substacks that are ready to have masks generated for them
		for(currSubstack = 0; currSubstack < substackNames.length; currSubstack++) {
	
			print("Processing substack ", substackNames[currSubstack]);

			//Get the TCS arrays we need to create masks for and their info
			tcsArrays = createTCSArrays(numberOfLoops, selection);

			//Fill them with info from old processed TCS values if they exist
			tcsStatusTable = directories[1]+imageNameRaw+"/TCS Status Substack(" + substackNames[currSubstack] +").csv";
			tcsArraysWithExisting = fillTCSArraysWithExisting(tcsStatusTable, numberOfLoops, tcsArrays);

			//Get the TCS values of old, and our new TCS values
			tcsValueOld = getOrCreateTableColumn(tcsStatusTable, "TCS", -1, numberOfLoops);
			tcsValueNew = Array.slice(tcsArrays, 0, numberOfLoops);
			
			//Get the array indices of old TCS values that aren't present in the new
			nonMatchingIndices = identifyMissingTCSIndices(tcsValueOld, tcsValueNew);

			//If there are actually old TCS values that aren't in the new one
			if(nonMatchingIndices[0] != -1) {

				//Get a big array of all our old and new tcs info stuck together
				nearlyDone = fillWithMissingTCSValues(nonMatchingIndices, tcsStatusTable, tcsArraysWithExisting, numberOfLoops);

				//Find out how long each one is meant to be and what to cut
				sliceBy = nearlyDone[0];
				sliceInto = cutUp;
			
			//Else
			} else {

				//What we're cutting up is our new with old filled in
				sliceBy = numberOfLoops;
				sliceInto = tcsArraysWithExisting;

			}

			//Cut up either our new w/ old filled in and missing stacked
			//Or, our new w/ old filled in
			tcsValue = Array.slice(sliceInto, 0, sliceBy);
			tcsMasksGenerated = Array.slice(sliceInto, sliceBy, sliceBy*2);
			tcsQCChecked = Array.slice(sliceInto, (sliceBy*2), sliceBy*3);
			tcsAnalysed = Array.slice(sliceInto, (sliceBy*3), sliceBy*4);
	
			//Loop through each TCS value the user has specified
			for(TCSLoops=0; TCSLoops<tcsValue.length; TCSLoops++) {
	
				//If we haven't generated all the masks for the current TCS value
				if(tcsMasksGenerated[TCSLoops] == -1) {
	
					print("Processing TCS value of ", tcsValue[TCSLoops]);				
	
					//This is the directory for the current TCS
					TCSDir=directories[1]+imageNameRaw+"/"+"TCS"+tcsValue[TCSLoops]+"/";
					TCSMasks = TCSDir + "Cell Masks/";
					makeDirectories(newArray(TCSDir, TCSMasks));
	
					//Retrieve the cell coordinates for the current substack
					print("Retrieving cell coordinates");
	
					substackFileSuffix = "Substack (" + substackNames[currSubstack] + ")";
					substackCoordinatesLoc = directories[1] + imageNameRaw + "/Cell Coordinates/" + "CP Coordinates for " + substackFileSuffix + ".csv";
	
					xCoords = getTableColumn(substackCoordinatesLoc, 'X');
					yCoords = getTableColumn(substackCoordinatesLoc, 'Y');
					xOpt = getOrCreateTableColumn(substackCoordinatesLoc, "xOpt", -1, xCoords.length);
					yOpt = getOrCreateTableColumn(substackCoordinatesLoc, "yOpt", -1, xCoords.length);
					optimalThreshold = getOrCreateTableColumn(substackCoordinatesLoc, "Optimal Threshold", -1, xCoords.length);
	
					cellMaskTable = TCSDir + "Substack (" + substackNames[currSubstack] + ") Mask Generation.csv";
	
					//Retrieving the status of each mask we need to generate for the current substack (and TCS)
					print("Retrieving mask generation status");
	
					maskName = getOrCreateTableColumn(cellMaskTable, "Mask Name", -1, xCoords.length);
					maskTry = getOrCreateTableColumn(cellMaskTable, "Mask Try", -1, xCoords.length);
					maskSuccess = getOrCreateTableColumn(cellMaskTable, "Mask Success", -1, xCoords.length);
					maskQA = getOrCreateTableColumn(cellMaskTable, "Mask QA", -1, xCoords.length);
					maskQuant = getOrCreateTableColumn(cellMaskTable, "Mask Quantified", -1, xCoords.length);
	
					//If we're after our first TCS loop
					if(TCSLoops > 0) {
						print("Masks generated for previous TCS value");
						prevTCSDir = directories[1]+imageNameRaw+"/"+"TCS"+tcsValue[TCSLoops-1]+"/";
					} else {
						prevTCSDir = 'none';
					}
	
					//Get previous mask success statuses as if they failed at a lower TCS, they will fail at a higher value so
					//no point attempting them
					prevTCSCellMaskTable = prevTCSDir + "Substack (" + substackNames[currSubstack] + ") Mask Generation.csv";
					prevMaskSuccess = getOrCreateTableColumn(prevTCSCellMaskTable, "Mask Success", 1, xCoords.length);

					//This is here for debugging
					saved = 0;
					
					//We now loop through all the cells for this substack and TCS value
					for(currCell=0; currCell<xCoords.length; currCell++) {
	
						rawCellName = substackNames[currSubstack] + " x " + xCoords[currCell] +  " y " + yCoords[currCell] + " .tif";
	
						maskName[currCell] = "Candidate mask for " + rawCellName;
					
						//If we haven't tried to make a mask for this image, and it didn't fail at a smaller TCS value (if it failed at a previous value, it
						//won't succeed at a higher one) then we proceed with mask generation
						if(maskTry[currCell]==-1 && prevMaskSuccess[currCell]==1) {
	
							print("Generating mask for ", maskName[currCell]);
	
							//This is an array to store the size of the local region in pixels (i.e. 120um in pixels)
							LRLengthPixels=(LRSize*(1/iniValues[0]));
							//[3] is size of the local region, [0] is the pixel size
	
							//Here we work out the number of pixels that represent 5 microns so we can use this to calculate if the coordinates are within the 5um buffer zone
							//of the edge of the image
							fiveMicronsInPixels=5*(1/iniValues[0]);
							
							avgProjImageLoc = directories[1]+imageNameRaw+"/Cell Coordinate Masks/CP mask for " + substackFileSuffix + ".tif";
							openAndCalibrateImage(avgProjImageLoc, iniValues);
							proceed = coordinatesWithinBuffer(avgProjImageLoc, xCoords[currCell], yCoords[currCell], fiveMicronsInPixels);	
							//If the y coordinate isn't less than 5 microns from the bottom or top edges of the image, and the x coordinate isn't less than 5 pixels from the width, then we
							//proceed
	
							//If the coordinates for the mask are far enough from the edge of the image, proceed
							if(proceed == true){
	
								print("Base coordinates are far enough from the edges of the image to proceed");
	
								//This array stores the width and height of our image so we can check against these
								selectWindow(File.getName(avgProjImageLoc));
	
								//Making and saving local regions, running first Otsu method and getting initial value on which to base iterative process	
								print("Coordinate number " + (currCell+1) + "/" + xCoords.length);
	
								lrImageName = "Local region for " + rawCellName;

								print('lrImageName: ' + lrImageName);
	
								lrSaveLoc = directories[1] + imageNameRaw + "/" + "Local Regions/" + lrImageName;

								print('lrSaveLoc: ' + lrSaveLoc);

								print('avgProjImageLoc: ' + avgProjImageLoc);
	
								LRCoords = getLRCoords(avgProjImageLoc, newArray(xCoords[currCell], yCoords[currCell]), LRLengthPixels);
	
								//Either make or read in a previously made local region image centered on the coordinates
								makeOrRetrieveLR(lrSaveLoc, LRCoords, LRLengthPixels, avgProjImageLoc);	
	
								//Adjust the coordinates so that they sit on the maxima of the cell in the local region
								lrCoordinateValues = findOrRetrieveOptimalCoordinates(avgProjImageLoc, LRCoords, xCoords, yCoords, xOpt, yOpt, optimalThreshold, currCell, substackCoordinatesLoc);
								
								initialThreshold = lrCoordinateValues[2];
								topValue = lrCoordinateValues[3];
								
								//Here we are finding the same connected regions using the maxima as our point selection and then measuring the area
								//of the connected region to get an initial area size associated with the starting otsu value
								firstArea = getCurrentMaskArea(lrCoordinateValues[0], lrCoordinateValues[1], initialThreshold);
								
								//Here we check the area output, and if it fits in certain conditions we either proceed with the iterative thresholding or move onto the next cell - more explanation can be found
								//with the corresponding functions for each condition
								
								//If it less than our lower limit, then we check if its touching edges and it not, we keep iterating
								nextIteration = false;
								touching = tooCloseToEdge("Connected", fiveMicronsInPixels);
	
								print("Current area is = "+firstArea+"um^2");
	
								//If -1, then the mask has failed
								//If 0, then the masks have passed
								//If 1, then we keep iterating
								stabilised = false;
								nextIteration = getMaskStatus(firstArea, tcsValue[TCSLoops], selection[2], touching, stabilised);
								
								nextIteration = iterativeThresholding(nextIteration, initialThreshold, firstArea, tcsValue, TCSLoops, topValue, lrCoordinateValues);

								//If the mask has passed, save it
								if(nextIteration == 0) {
									print("Mask successfully generated; saving");

									if(saved > 0) {
										prevSaveLoc = maskSaveLoc;
									}
									
									maskSaveLoc = TCSMasks + maskName[currCell];

									if(saved > 0) {
										open(prevSaveLoc);
										print(TCSMasks + maskName[currCell-1]);
										prevImageName = getTitle();
										print(prevSaveLoc);
										imageCalculator("Subtract create", "Connected", prevImageName);
										selectWindow("Result of Connected");
										getRawStatistics(subnPixels, submean, submin, submax, substd, subhistogram);
										print('Max diff: ' + submax);
										
										if(submax == 0) {
											print('Issue with this one');
											setBatchMode("exit and display");
											waitForUser('check');
										}
	
										selectWindow("Result of Connected");
										run('Close');
										selectWindow(prevImageName);
										run('Close');
	
									}
									
									saveImage("Connected", maskSaveLoc);
									maskSuccess[currCell] = 1;
									saved +=1;
								}
								
								selectWindow("Connected");	
								run("Close");
	
								selectWindow("LR");
								run("Close");
							}
	
							selectWindow(File.getName(avgProjImageLoc));
							run("Close");
	
							maskTry[currCell] = 1;
	
							if(maskSuccess[currCell] == -1) {
								maskSuccess[currCell] = 0;
								print("Mask generation failed");
							}
	
							saveMaskGenerationTable(maskName, maskTry, maskSuccess, maskQA, maskQuant, cellMaskTable);
		
							//Update and save our cellMaskTable = TCSDir + "Mask Generation.csv" table
	
						} else if (prevMaskSuccess[currCell]==0) {
							maskTry[currCell] = 1;
							maskSuccess[currCell] = 0;
							saveMaskGenerationTable(maskName, maskTry, maskSuccess, maskQA, maskQuant, cellMaskTable);
						}

					}
	
					tcsMasksGenerated[TCSLoops] = 1;
	
					saveTCSStatusTable(substackNames[currSubstack], tcsValue, tcsMasksGenerated, tcsQCChecked, tcsAnalysed, tcsStatusTable);
	
				}
			}
		}

	}
}

print("Cell Mask Generation Complete");
