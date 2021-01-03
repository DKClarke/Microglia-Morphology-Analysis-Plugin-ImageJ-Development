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
		
	//Here we loop through the strings and add a box for numeric input for each
	for(i=0; i<strings.length-1; i++) {
		Dialog.addNumber(strings[i], 0);
	}
	Dialog.addNumber(strings[strings.length-1], 120);
			
	Dialog.show();
						
	//Retrieve user inputs and store the selections in the selection array
	selection = newArray(strings.length);
	for(i=0; i<strings.length; i++) {
		selection[i] = Dialog.getNumber();
	}

	return selection;

}

function makeImageNamesArray(directories, imageNameRaw, currSubstack, currXCoord, currYCoord) {

	//We create an array to store different names we need for our mask generation where [0] is the name to save an image as, [1] is the
	//fileName, and [2] is the LRName. [0] and [1] are repeats as we edit them differently within functions
	imageNamesArray = newArray(directories[1] + imageNameRaw + "/Candidate Cell Masks/"+"Candidate mask for " + currSubstack + " x " + currXCoord +  " y " + currYCoord + " .tif", 
	"Candidate mask for " + currSubstack + " x " + currXCoord +  " y " + currYCoord + " .tif",
	"Local region for " + currSubstack + " x " + currXCoord +  " y " + currYCoord + " .tif");

	return imageNamesArray;


}

function openAndCalibrateAvgProjImage(avgProjImageLoc, iniValues) {
	//We open the image then calibrate it before converting it to 8-bit
	open(avgProjImageLoc);
	avgProjImage = File.getName(avgProjImageLoc);
	selectWindow(avgProjImage);
	run("Properties...", "channels=1 slices=1 frames=1 unit=um pixel_width="+iniValues[0]+" pixel_height="+iniValues[1]+" voxel_depth="+iniValues[2]+"");
}

function coordinatesWithinBuffer(avgProjImageLoc, currXCoord, currYCoord, bufferInPixels) {
	selectWindow(File.getName(avgProjImageLoc));
	getDimensions(originalWidth, originalHeight, originalChannels, originalSlices, originalFrames);
	
	//Calculate if our y or x coordinates or outside the bufer in pixels
	yInsideBuffer = (currYCoord > bufferInPixels) || (currYCoord < (originalHeight - bufferInPixels));
	xInsideBuffer = (currXCoord > bufferInPixels) || (currXCoord < (originalWidth - bufferInPixels));

	return yInsideBuffer && xInsideBuffer;

}

function getLRCoords(cellLocCoords, LRLengthPixels) {


	//Here we store x and y values that we would use to draw a 120x120um square aruond our coordinate - we store the coordinates
	//that would be the top left corner of this square as that is what we need to input to draw it
	LRCoords = newArray(cellLocCoords[0]-(LRLengthPixels/2), cellLocCoords[1]-(LRLengthPixels/2));
	//[0] is xcordn, [1] is ycordn

	//Idea here is that if our x or y coordinates are less than half a LR length away from the edge, the LR length we create is half the 
	//usual length + however far our coordinate is from the edge
	//We also set our rectangle making coordinates to 0 if they would be less than 0 (i.e. our coordinates are less than half the LR distance
	//from the pictre edges

	//For each of our cell coordinates
	for(currCoord = 0; currCoord < cellLocCoords.length; currCoord++) {

		//If that coordinate is too close to the bottom left of the image for us to create a
		//local region with the existing LR coordinates
		if(cellLocCoords[currCoord] < LRLengthPixels/2) {

			//Set our LR coord to 0 (else it would be -ve)
			LRCoords[currCoord] = 0;

		}
	}

	return LRCoords;


}


function getLRLengths(cellLocCoords, dimensionsArray, LRLengthPixels) {

	//This array is created to store the length in x and y of the local region we're going to draw - in theory it should be 120um
	//for both directions but if our coordinate is close enough to the edge of our image that this isn't true, we adjust it
	LRLengthArray = newArray(LRLengthPixels, LRLengthPixels);
	//[0] is xLength, [1] is yLength

	//For each of our cell coordinates
	for(currCoord = 0; currCoord < cellLocCoords.length; currCoord++) {

		//If that coordinate is too close to the bottom left of the image for us to create a
		//local region with the existing LR coordinates
		if(cellLocCoords[currCoord] < LRLengthPixels/2) {

			//Set the length to be shorter than the full length depending on
			//where our coordinate is
			LRLengthArray[currCoord]=(LRLengthPixels/2) + cellLocCoords[currCoord];

		//Otherwise if the coordinate is too close to the top right of the image
		} else if(cellLocCoords[currCoord] > (dimensionsArray[currCoord] - (LRLengthPixels/2))) {

			//Adjust the size of the local region we create accordingly
			LRLengthArray[currCoord]=(LRLengthPixels/2) + dimensionsArray[currCoord] - cellLocCoords[currCoord];

		}
	}

	return LRLengthArray;

}

function createLRImage(avgProjImageLoc, LRCoords, LRLengthArray) {

	imageTitle = File.getName(avgProjImageLoc);
	selectWindow(imageTitle);
	run("Select None");

	//Here we make our local region based on all the values we've calculated
	makeRectangle(LRCoords[0], LRCoords[1], LRLengthArray[0], LRLengthArray[1]);
	run("Duplicate...", " ");
	tifLess = File.getNameWithoutExtension(avgProjImageLoc);
	selectWindow(tifLess + "-1.tif");
	rename("LR");
	run("Select None");


}

function getOtsuValue(avgProjImageLoc, xCoord, yCoord) {

	//We then auto threshold the LR and then get the lower and upper threshold levels from the otsu method and call the lower threshold
	//otsu
	selectWindow("LR");
	setAutoThreshold("Otsu dark");
	selectWindow("LR");
	getThreshold(otsu, upper);
	print("Finding connected pixels from CP using threshold");

	//We get the grey value at that point selection, and then if the lower threshold of the image
	//is bigger than that value, we set it to that value
	selectWindow(File.getName(avgProjImageLoc));
	pointValue = (getPixel(xCoord, yCoord)) - 1;
	if(otsu>=pointValue) {
		otsu = pointValue-1;
	}

	return otsu;

}

function getConnectedMask(xCoord, yCoord, thresholdVal) {

	//We then make the point on our image and find all connected pixels to that point that have grey values greater than the otsu value
	selectWindow("LR");
	makePoint(xCoord, yCoord);
	setBackgroundColor(0,0,0);
	run("Find Connected Regions", "allow_diagonal display_image_for_each start_from_point regions_for_values_over="+thresholdVal+" minimum_number_of_points=1 stop_after=1");
	imgNamemask=getTitle();
	rename("Connected");
	print("Connected pixels found");

}

function findMaximaInCoords() {

	selectWindow("Connected");
	run("Create Selection");
	getSelectionCoordinates(xpoints, ypoints);

	//We clear outside of our selection in our LR, then find the maxima in that and get the coordinates of the maxima
	//to store these coordinates as the optimal point selection location

	//We need to find the optimal location as we want our point selection to be on the brightest pixel on our target cell
	//to ensure that our point selection isn't on a local minima, which whould make finding connected pixels that are 
	//actually from our target cell very error-prone
	
	print("Fine-tuning CP point selection based on mask");
	selectWindow("LR");
	run("Duplicate...", " ");
	selectWindow("LR-1");
	makeSelection("freehand", xpoints, ypoints);
	run("Clear Outside");
	List.setMeasurements;

	//Here we get the max value in the image and get out the point selection associated with the maxima using the
	//"find maxima" function			
	topValue = List.getValue("Max");
	run("Select None");
	run("Find Maxima...", "noise=1000 output=[Point Selection]");
	getSelectionCoordinates(tempX, tempY);
	adjustedCellCoords = newArray(tempX[0], tempY[0], topValue);
	selectWindow("LR-1");
	run("Close");
	selectWindow("Connected");
	run("Close");

	return adjustedCellCoords;

}


function saveLRImage(lrSaveLoc) {

	//Now that we're certain we've got the optimal coordinates, we save our LR image
	selectWindow("LR");
	saveAs("tiff", lrSaveLoc);
	selectWindow(File.getName(lrSaveLoc));
	rename("LR");

}

function getCurrentMaskArea(xCoord, yCoord, threshold) {

	//Here we are finding the same connected regions using the maxima as our point selection and then measuring the area
	//of the connected region to get an initial area size associated with the starting otsu value
	getConnectedMask(xCoord, yCoord, threshold);

	selectWindow("Connected");
	run("Create Selection");
	getStatistics(area);

	return area;


}

function tooCloseToEdge(imageName, bufferSize) {

	//Takes the mask of the cell and turns it into its bounding quadrilateral, 
	//then gets an array of all the coordinates of that quadrilateral
	selectWindow(imageName);
	getDimensions(functionWidth, functionHeight, functionChannels, functionSlices, functionFrames);
	run("Create Selection");
	getSelectionBounds(xF, yF, widthF, heightF);

	xTouchesEdge = false;
	if(xF <= bufferSize || (xF+widthF) >= (functionWidth - bufferSize)) {
		xTouchesEdge = true;
	}

	yTouchesEdge = false;
	if(yF <= bufferSize || (yF+heightF) >= (functionHeight - bufferSize)) {
		yTouchesEdge = true;
	}

	return xTouchesEdge || yTouchesEdge;


}

function getMaskStatus(area, currentTCS, TCSRange, touching, stabilised) {

	//limits is an array to store the lower and upper limits of the cell area we're using within this TCS loop, calculated
	//according to the error the user input
	limits = newArray(currentTCS-TCSRange, currentTCS+TCSRange);
	//Selection: //[0] is TCSLower, [1] is TCSUpper, [2] is range, [3] is increment, [4] is framesToKeep, [5] is trace
	//Limits: [0] is lower limit, [1] is upper
	
	nextIteration = 0;

	if (area<limits[0]) {

		//If we're checking for touching below the area limits or once the image 
		//has stabilized, touching means we disregard this cell and so we set 
		//output to false
		if(touching == true) {
			nextIteration = -1;
		} else {
			nextIteration = 1;
		}
	
	//If its within our limits, we check if its touching edges, and if it isn't touching any edges we save it, else we keep going
	} else if (area<=limits[1] && area>=limits[0]) {

		//If we're checking for touching below the area limits or once the image 
		//has stabilized, touching means we disregard this cell and so we set 
		//output to false
		if(stabilised == true && touching == true) {
			nextIteration = -1;
		}
		
		//Otherwise if we're checking for a cell within the area limits, this 
		//isn't necessarily the only outcome so we set output to true to continue
		//iterating to try and find a new threshold value that means we're in the 
		//limits but not touching
		if(stabilised == false && touching == true) {
			nextIteration = 1;
		}

		//Otherwise if the image is within the area limits or has a stabilised area, 
		//we clear our selection, and save the image using the saveName and fileName
		//inputs before setting output to false as we're now done with this cell
		if(touching == false) {
			nextIteration = 0;
		}

	//If we're above the limits, we continue iterating
	} else if (area>limits[1]) {

		if(stabilised == true) {
			nextIteration = -1;
		} else {
			nextIteration=1;	
		}

	}

	return nextIteration;

}

function saveGeneratedMask(saveLoc) {

	selectWindow("Connected");
	run("Select None");
	saveAs("tiff", saveLoc);
	selectWindow(File.getName(saveLoc));
	rename("Connected");

}

//Function to check if the inputValue is above the topLimit - this is so that if 
//our thresholding calculated value ends up above the highest grey value in the 
//image then we set inputValue to that top value
function valueCheck(inputValue, topLimit) {
	
	if(inputValue>=topLimit) {
		inputValue = topLimit-1;
	}

	//We want a rounded threshold value since the images are in 8-bit, so we do 
	//that before returning it
	return round(inputValue);
}

function calculateNextThreshold(t1, a1, ms, n) {

	firstClause = t1;
	secondClause = t1 * ((a1 - ms) / (n * ms));

	nextThresholdRaw = firstClause + secondClause;

	return nextThresholdRaw;

}

function substacksToUse(substackTableLoc, nameCol, processedCol, QCCol) {

	//We return an array of substack names to use if they have been processed an QAs
	substackNames = getTableColumn(substackTableLoc, nameCol);
	processed = getTableColumn(substackTableLoc, processedCol);
	qaValue = getTableColumn(substackTableLoc, QCCol);

	output = newArray(1);
	added = 0;
	for(currSub = 0; currSub<substackNames.length; currSub++) {
		if(processed[currSub] == 1 && qaValue[currSub] == 1) {
			if(added == 0) {
				output[0] = substackNames[currSub];
			} else {
				output = Array.concat(output, newArray(substackNames[currSub]));
			}
		}
	}

	return output;

}

function saveMaskGenerationTable(maskName, maskTry, maskSuccess, saveLoc) {
	//Save these arrays into a table
	Table.create("Mask Generation.csv");
	selectWindow("Mask Generation.csv");
	Table.setColumn("Mask Name", maskName);
	Table.setColumn("Mask Try", maskTry);
	Table.setColumn("Mask Success", maskSuccess);
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

function getWorkingAndStorageDirectories(){

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

    images_in_storage = listFilesAndFilesSubDirectories(directories[3], '.tif');
    if(images_in_storage.length == 0) {
    	exit('No .tif images in image storage, exiting plugin');
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
		if (File.isDirectory(fullPath)==0 && indexOf(toLowerCase(fullPath), toLowerCase(subString))>-1) {
			
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

	open(fileLoc);
	tableName = Table.title;
	selectWindow(tableName);

	outputArray = Table.getColumn(colName);

	selectWindow(tableName);
	run("Close");

	return outputArray;

}


function findFileWithFormat(folder, fileFormat) {

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
		exit("No file found");
	} else {
		return storeIt;
	}

}

//This is a function to retrieve the data from the ini file. The ini file contains calibration information for the 
//entire experiment that we use to calibrate our images. iniFolder is the folder within which the ini file is located, 
//and iniValues is an array we pass into the function that we fill with calibration values before returning it	
function getIniData(iniFolder, iniStrings) {

	//Find our ini file
	iniLocations = findFileWithFormat(iniFolder, "ini");
	if(iniLocations.length > 1) {
		exit("More than 1 ini file found, exiting plugin");
	} else {
		print(".ini file found at", iniLocations[0]);
		iniToOpen = iniLocations[0];
	}

	iniValues = parseIniValues(iniStrings, iniToOpen);
		
	return iniValues;
}

function parseIniValues(iniStrings, iniToOpen) {
		
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

function getOrCreateTableColumn(tableLoc, columnName, defaultValue, defaultLength) {
	if(File.exists(tableLoc) == 1) {
		outputArray = getTableColumn(tableLoc, columnName);
	} else {
		outputArray = newArray(defaultLength);
		Array.fill(outputArray, defaultValue);
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

function saveSubstackCoordinatesLocTable(xCoords, yCoords, xOpt, yOpt, saveLoc) {
	//Save these arrays into a table
	Table.create(File.getName(saveLoc));
	selectWindow(File.getName(saveLoc));
	Table.setColumn("X", xCoords);
	Table.setColumn("Y", yCoords);
	Table.setColumn("xOpt", xOpt);
	Table.setColumn("yOpt", yOpt);
	Table.save(saveLoc);
	selectWindow(File.getName(saveLoc));
	run("Close");

}

function makeOrRetrieveLR(lrSaveLoc, xCoord, yCoord, LRLengthPixels, avgProjImageLoc) {

	//If we already have made a LR image, retrieve it
	if(File.exists(lrSaveLoc) == 1) {
		open(lrSaveLoc);
		selectWindow(File.getName(lrSaveLoc));
		rename("LR");

	//Else make it and save it
	} else {

		print("Making local region image centered on X: " + xCoords[currCell] + " Y: " + yCoords[currCell]);

		LRCoords = getLRCoords(newArray(xCoords[currCell], yCoords[currCell]), LRLengthPixels);
		//Here we store x and y values that we would use to draw a 120x120um square aruond our coordinate - we store the coordinates
		//that would be the top left corner of this square as that is what we need to input to draw it	

		//Issues with this
		createLRImage(avgProjImageLoc, LRCoords, newArray(LRLengthPixels, LRLengthPixels));

		//Now that we're certain we've got the optimal coordinates, we save our LR image
		saveLRImage(lrSaveLoc);

	}

}

function findOrRetrieveOptimalCoordinates(avgProjImageLoc, xCoords, yCoords, xOpt, yOpt, currCell, substackCoordinatesLoc) {

	//If we don't have any optimised cell coordinates yet for this cell, find them
	if(xOpt[currCell] == -1) {

		//Here if we've already made the LR image, no need to remake it - just load it in
		//Also, if we already have the optimal coordinate for that local region, save it in a table rather than
		//recalculating
		//Save optimal coordinates in the CP coordinate for substack table

		otsu = getOtsuValue(avgProjImageLoc, xCoords[currCell], yCoords[currCell]);

		print("Initial threshold value of " + otsu);

		selectWindow("LR");
		getDimensions(LRWidth, LRHeight, LRChannels, LRSlices, LRFrames);

		makePoint(LRWidth/2, LRHeight/2);
		initialTopValue = getValue("Max");
		run("Select None");

		initialThreshold = valueCheck(otsu, initialTopValue);
		//Get a connected mask centered on the centre of the local region - as this is centered on our chosen cell coordinate
		getConnectedMask(LRWidth/2, LRHeight/2, initialThreshold);

		//Get the coordinates of the maxima in the local region
		maximaCoordinates = findMaximaInCoords();
		xOpt[currCell] = maximaCoordinates[0];
		yOpt[currCell] = maximaCoordinates[1];

		saveSubstackCoordinatesLocTable(xCoords, yCoords, xOpt, yOpt, substackCoordinatesLoc);
	
	//Else, store them
	} else {

		selectWindow("LR");
		run("Select None");
		makePoint(xOpt[currCell], yOpt[currCell]);
		topValue = getValue("Max");
		run("Select None");
		maximaCoordinates = newArray(xOpt[currCell], yOpt[currCell], topValue);

	}

	return maximaCoordinates;

}

//setBatchMode(true);

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

		imageNameRaw = File.getNameWithoutExtension(imageName[currImage]);

		statusTable = directories[1]+imageNameRaw+"/Cell Coordinate Masks/Cell Position Marking.csv";

		if(File.exists(statusTable) != 1) {
			exit("Run cell detection first");
		}

		substackNames = substacksToUse(statusTable, 'Substack', 'Processed', 'QC');

		for(currSubstack = 0; currSubstack < substackNames.length; currSubstack++) {

			tcsStatusTable = directories[1]+imageNameRaw+"/TCS Status Substack(" + substackNames[currSubstack] +").csv";

			tcsValue = getOrCreateTableColumn(tcsStatusTable, "TCS", -1, numberOfLoops);
			tcsMasksGenerated = getOrCreateTableColumn(tcsStatusTable, "Masks Generated", -1, numberOfLoops);
			tcsQCChecked = getOrCreateTableColumn(tcsStatusTable, "QC Checked", -1, numberOfLoops);
			tcsAnalysed = getOrCreateTableColumn(tcsStatusTable, "Analysed", -1, numberOfLoops);

			if(tcsValue[0] == -1) {
				for(TCSLoops=0; TCSLoops<numberOfLoops; TCSLoops++) {
					tcsValue[TCSLoops] = selection[0]+(selection[3]*TCSLoops);
				}
			}

			for(TCSLoops=0; TCSLoops<tcsValue.length; TCSLoops++) {

				if(tcsMasksGenerated[TCSLoops] == -1) {

					//This is the directory for the current TCS
					TCSDir=directories[1]+imageNameRaw+"/"+"TCS"+tcsValue[TCSLoops]+"/";
					TCSMasks = TCSDir + "Cell Masks/";

					makeDirectories(newArray(TCSDir, TCSMasks));

					substackFileSuffix = "Substack (" + substackNames[currSubstack] + ")";
					substackCoordinatesLoc = directories[1] + imageNameRaw + "/Cell Coordinates/" + "CP Coordinates for " + substackFileSuffix + ".csv";

					xCoords = getTableColumn(substackCoordinatesLoc, 'X');
					yCoords = getTableColumn(substackCoordinatesLoc, 'Y');
					xOpt = getOrCreateTableColumn(substackCoordinatesLoc, "xOpt", -1, xCoords.length);
					yOpt = getOrCreateTableColumn(substackCoordinatesLoc, "yOpt", -1, xCoords.length);

					cellMaskTable = TCSDir + "Mask Generation.csv";

					maskName = getOrCreateTableColumn(cellMaskTable, "Mask Name", -1, xCoords.length);
					maskTry = getOrCreateTableColumn(cellMaskTable, "Mask Try", -1, xCoords.length);
					maskSuccess = getOrCreateTableColumn(cellMaskTable, "Mask Success", -1, xCoords.length);

					if(TCSLoops > 0) {
						prevTCSDir = directories[1]+imageNameRaw+"/"+"TCS"+tcsValue[TCSLoops-1]+"/";
					} else {
						prevTCSDir = 'none';
					}

					prevTCSCellMaskTable = prevTCSDir + "Mask Generation.csv";
					prevMaskSuccess = getOrCreateTableColumn(prevTCSCellMaskTable, "Mask Success", 1, xCoords.length);

					//We now loop through all the cells for this given input image
					for(currCell=0; currCell<xCoords.length; currCell++) {
					
						//If the current mask hasn't been tried, and making the mask previously was a success then we try to make a mask - the reason we check previously
						//is because our TCS sizes increase with each loop, so if we couldn't make a mask on a previous loop where the TCS was smaller, that means the mask 
						//must have been touching the edges of the image, so with a larger TCS, then we're guaranteed that the mask will touch the edges so we don't bother
						//trying to make a mask for it anymore
						if(maskTry[currCell]==-1 && prevMaskSuccess[currCell]==1) {

							imageNamesArray = makeImageNamesArray(directories, imageNameRaw, substackNames[currSubstack], xCoords[currCell], yCoords[currCell]);
							//[0] is saveName, [1] is fileName, [2] is LRName

							maskName[currCell] = File.getName(imageNamesArray[0]);

							//This is an array to store the size of the local region in pixels (i.e. 120um in pixels)
							LRLengthPixels=(LRSize*(1/iniValues[0]));
							//[3] is size of the local region, [0] is the pixel size

							//Here we work out the number of pixels that represent 5 microns so we can use this to calculate if the coordinates are within the 5um buffer zone
							//of the edge of the image
							fiveMicronsInPixels=5*(1/iniValues[0]);

							avgProjImageLoc = directories[1]+imageNameRaw+"/Cell Coordinate Masks/CP mask for " + substackFileSuffix + ".tif";
							openAndCalibrateAvgProjImage(avgProjImageLoc, iniValues);
							proceed = coordinatesWithinBuffer(avgProjImageLoc, xCoords[currCell], yCoords[currCell], fiveMicronsInPixels);	
	
							//If the y coordinate isn't less than 5 microns from the bottom or top edges of the image, and the x coordinate isn't less than 5 pixels from the width, then we
							//proceed

							if(proceed == true){
	
								//This array stores the width and height of our image so we can check against these
								selectWindow(File.getName(avgProjImageLoc));

								//Making and saving local regions, running first Otsu method and getting initial value on which to base iterative process	
								print("Coordinate number " + (currCell+1) + "/" + xCoords.length);

								lrSaveLoc = directories[1] + imageNameRaw + "/" + "Local Regions/" + imageNamesArray[2];

								makeOrRetrieveLR(lrSaveLoc, xCoords[currCell], yCoords[currCell], LRLengthPixels, avgProjImageLoc);	

								maximaCoordinates = findOrRetrieveOptimalCoordinates(avgProjImageLoc, xCoords, yCoords, xOpt, yOpt, currCell, substackCoordinatesLoc);
								
								print('Previous coordinates');
								print(xCoords[currCell]);
								print(yCoords[currCell]);

								print('Maxima coordinates');
								print(maximaCoordinates[0]);
								print(maximaCoordinates[1]);

								topValue = maximaCoordinates[2];

								//Here we are finding the same connected regions using the maxima as our point selection and then measuring the area
								//of the connected region to get an initial area size associated with the starting otsu value
								firstArea = getCurrentMaskArea(maximaCoordinates[0], maximaCoordinates[1], otsu);
								
								//Here we check the area output, and if it fits in certain conditions we either proceed with the iterative thresholding or move onto the next cell - more explanation can be found
								//with the corresponding functions for each condition
								
								//If it less than our lower limit, then we check if its touching edges and it not, we keep iterating
								nextIteration = false;
								touching = tooCloseToEdge("Connected", fiveMicronsInPixels);

								print("Area is = "+firstArea+"um^2 +/- "+selection[2]+"um^2");

								//If -1, then the mask has failed
								//If 0, then the masks have passed
								//If 1, then we keep iterating
								stabilised = false;
								nextIteration = getMaskStatus(firstArea, tcsValue[TCSLoops], selection[2], touching, stabilised);

								//These variables are changed depending on how many iterations a mask has stabilised for (regardless of whether it fits
								// the TCS +/- the range, as if it stabilized 3 times we keep it), and loopcount ticks up each iteration we go through
								//as we use this value to change the otsu we use for the subsequent iteration 
								stabilisedCount = 0;
								loopCount = 0;
		
								//Here if we are proceeding with the iterative thresholding
								while (nextIteration==1) {

									print("Mask doesn't meet stopping requirements, continuing to iterate");
									print(stabilisedCount);
									print(loopCount);
									print(touching);
									waitForUser("Check printouts");

									selectWindow("Connected");
									run("Close");
					
									loopCount++; //Each iteration we increase loopCount, this modifies how we alter the threshold value
		
									//This variable stores the next threshold value we'll use based on a formula outlined later
									if(loopCount == 1) {
										t1 = otsu;
										a1 = firstArea;
									} else {
										t1 = nextThreshold;
										a1 = areaNew;
									}

									ms = tcsValue[TCSLoops];
									n = loopCount;

									nextThresholdRaw = calculateNextThreshold(t1, a1, ms, n);

									//print("nextThresh: ", otsuVariables[1]);
									//print("otsuNorm: ", otsu/255);
									//print("area: ", area);
									//print("TCS: ", currentLoopValues[0]);
									//print("Loop count: ", maskGenerationVariables[1]);
											
									//Check if our next threshold is higher than the maximum pixel value in the image - if so, set to
									//maximal pixel value
									nextThreshold = valueCheck(nextThresholdRaw, topValue);
				
									//Here we get another area from our find connected regions
									//print("otsu to check: ", otsuVariables[1]);
									//print("bottom value: ", bottomValue);
									//print("top value: ", topValue);
									print("Threshold value of " + nextThreshold);
									areaNew = getCurrentMaskArea(maximaCoordinates[0], maximaCoordinates[1], nextThreshold);

									print("Area is = "+areaNew+"um^2 +/- "+selection[2]+"um^2");
					
									//If we get the same area for 3 iterations we exit the iterative process, so here we count identical areas 
									//(but if for any one instance they are not identical, we rest the counter)
									if (areaNew==a1){
										stabilisedCount++;
									} else {
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
					
									//print("Old area:" + area);
									//print("Old otsu: "+ otsu);
									//print("Current area: "+ areaNew);
									//print("Current otsu:" + otsuVariables[1]);
									//print("Stabilised:" + maskGenerationVariables[0]);
		
								} //Once the output of threshContinue==false, then we exit the process

								//If the mask has passed, save it
								if(nextIteration == 0) {
									print("Mask successfully generated; saving");
									maskSaveLoc = TCSMasks + imageNamesArray[1];
									saveGeneratedMask(maskSaveLoc);
									maskSuccess[currCell] = 1;
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

							Array.show(maskName, maskTry, maskSuccess);
							waitForUser("Check table");

							saveMaskGenerationTable(maskName, maskTry, maskSuccess, cellMaskTable);
		
							//Update and save our cellMaskTable = TCSDir + "Mask Generation.csv" table

						}
					}

					tcsMasksGenerated[TCSLoops] = 1;

					saveTCSStatusTable(substackNames[currSubstack], tcsValue, tcsMasksGenerated, tcsQCChecked, tcsAnalysed, tcsStatusTable);

				}
			}
		}
	}
}
