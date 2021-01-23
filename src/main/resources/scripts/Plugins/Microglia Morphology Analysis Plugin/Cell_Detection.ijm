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

function getOrCreateTableColumn(tableLoc, columnName, defaultValue, defaultLength) {

	//If our table exists, get our column
	if(File.exists(tableLoc) == 1) {
		outputArray = getTableColumn(tableLoc, columnName);
	} else {
		print("Table doesn't exist; creating array with default value of default length");
		outputArray = newArray(defaultLength);
		Array.fill(outputArray, defaultValue);
	}

	return outputArray;
}

//Work out whether to proceed with cell detection on this image
function proceedWithCellDetection(autoPassedQA, manualPassedQA, substacksMade, substacksPossible) {

	//Our default is we don't proceed with cell detection
	proceed = false;

	//If the image has passed either automatic or manual QA, set passedQA to true
	passedQA = false;
	if(autoPassedQA[currImage] == 1 || manualPassedQA[currImage] == 1) {
		passedQA = true;
	}

	//If we haven't already made all the substacks for this image, set madeAllSubstacks to false
	madeAllSubstacks = true;
	if(substacksMade[currImage] == 0 || (substacksPossible[currImage] == substacksMade[currImage])){
		madeAllSubstacks = false;
	}

	//If the image passed QA, and we still have substacks to make for it, set proceed to true
	if(passedQA == true && madeAllSubstacks == false) {
		proceed = true;
	}

	return proceed;

}

function getNoSubstacks(substacksPossible, iniValues, zBuffer) {

	//If we haven't calculated how many substacks we can make for the processed image
	if(substacksPossible == -1) {
		
		//Calculate how much Z depth there is in the stack
		zSize = iniValues[3] * iniValues[2];
		//Index 0 is xPxlSz, then yPxlSz, zPxlSz, ZperT, FperZ
		//Here we do the size of Z pixels * the number of Z per timepoint (i.e. number of Z slices)

		//Calculate how many 10um thick substacks we can make from this stack, including a user defined buffer size
		//between substacks
		noSubstacks = floor(zSize / (zBuffer+10));

	//If we have already calculated the number of stacks we can make, return this
	} else {
		noSubstacks = substacksPossible;
	}

	return noSubstacks;

}

function getSlicesForEachSubstack(noSubstacks, zBuffer) {

	//Fill maskGenerationArray with a string of the range of z planes to include in each substack
	maskGenerationArray = newArray(noSubstacks);
	for(currSubstack = 0; currSubstack < noSubstacks; currSubstack++){
		
		//Calculate what slices to start and end at for each substack
		startZ = (zBuffer * (currSubstack+1)) + (currSubstack * 10);
		maskGenerationArray[currSubstack] = toString(startZ) + '-' + toString(startZ + 10);
	}

	return maskGenerationArray;
}

function getMaximaCoordinates(imagePath, currMaskGenerationArray) {
	
	//Open the processed image and make sure the LUT is not inverted
	open(imagePath);
	if(is("Inverting LUT")==true) {
		run("Invert LUT");
	}

	//Make a substack from this image
	rename('Raw');
	run("Make Substack...", " slices="+currMaskGenerationArray+"");
	selectWindow('Raw');

	//Average project the substack
	run("Z Project...", "projection=[Average Intensity]");
	selectWindow("AVG_"+'Raw');
	rename("AVG");
				
	//Calibrate this average projection in pixels and convert to 8 bit
	getDimensions(width, height, channels, slices, frames);
	run("Properties...", "channels="+channels+" slices="+slices+" frames="+frames+" unit=pixels pixel_width=1 pixel_height=1 voxel_depth=1.0000000");
	run("8-bit");
	run("Clear Results");
		
	//Get the maxima of this image as cell locations
	selectWindow("AVG");
	run("Find Maxima...", "prominence=200 exclude output=List");
	selectWindow("Results");
	xPoints = Table.getColumn('X');
	yPoints = Table.getColumn('Y');
	selectWindow("Results");
	run("Close");

	//Return the array of these cell location coordinates
	outputArray = Array.concat(xPoints, yPoints);

	return outputArray;

}

function saveSubstackStatusTable(substackNames, processed, qcValue, saveLoc) {
	//Save these arrays into a table
	Table.create("Cell Position Marking.csv");
	selectWindow("Cell Position Marking.csv");
	Table.setColumn("Substack", substackNames);
	Table.setColumn("Processed", processed);
	Table.setColumn("QC", qcValue);
	Table.save(saveLoc);
	selectWindow("Cell Position Marking.csv");
	run("Close");
}

function saveMaskGenerationStatusTable(imageNameMasks, substacksPossible, substacksMade, saveLoc) {
	//Save these arrays into a table
	Table.create("Mask Generation Status.csv");
	selectWindow("Mask Generation Status.csv");
	Table.setColumn("Image Name", imageNameMasks);
	Table.setColumn("Number of Substacks to Make", substacksPossible);
	Table.setColumn("Number of Substacks Made", substacksMade);
	Table.save(saveLoc);
	selectWindow("Mask Generation Status.csv");
	run("Close");
}

function fillAndSaveSubstackCoordinatesTable(currentMaskGen, newX, newY, directories, imageNameRaw) {
					
	//Store these coordinates in a substack specific table for the image
	Table.create("CP coordinates for Substack (" + currentMaskGen + ").csv");
	if(newX.length == 0) {
		Table.setColumn("X", -1);
		Table.setColumn("Y", -1);
		Table.setColumn("xOpt", -1);
		Table.setColumn("yOpt", -1);
		Table.setColumn("Optimal Threshold", -1);)

	} else {
		Table.setColumn("X", newX);
		Table.setColumn("Y", newY);

		xOpt = Array.copy(newX);
		yOpt = Array.copy(newY);
		Array.fill(xOpt, -1);
		Array.fill(yOpt, -1);

		Table.setColumn("xOpt", xOpt);
		Table.setColumn("yOpt", yOpt);

		optimalThreshold = Array.copy(newY);
		Array.fill(optimalThreshold, -1);
		Table.setColumn("Optimal Threshold", optimalThreshold);

	}

	//Save this table
	saveLoc = directories[1]+imageNameRaw+"/Cell Coordinates/CP coordinates for Substack (" + currentMaskGen + ").csv";
	saveAs("Results", saveLoc);
	selectWindow(File.getName(saveLoc));
	run("Close");

}

function saveMaximaImages(directories, imageNameRaw, currMaskGen) {

	//Save the images we used to generate these maxima
	selectWindow("AVG");
	run("Select None");
	saveAs("tiff", directories[1] + imageNameRaw + "/Cell Coordinate Masks/CP mask for Substack (" + currMaskGen + ").tif");
	close("*");
}

function detectSubstackCellsSaveSubstackImages(directories, imageNameRaw, maskGenerationValue) {

	//Retrieve the coordinates in x and y of the maxima in the average projection of the image
	imagePath = directories[1] + imageNameRaw + "/" + imageNameRaw +" processed.tif";
	unformattedLocations = getMaximaCoordinates(imagePath, maskGenerationValue);

	newX = Array.slice(unformattedLocations, 0, unformattedLocations.length/2);
	newY = Array.slice(unformattedLocations, unformattedLocations.length/2);

	//Save our coordinates
	fillAndSaveSubstackCoordinatesTable(maskGenerationValue, newX, newY, directories, imageNameRaw);

	//Save our maxima images
	saveMaximaImages(directories, imageNameRaw, maskGenerationValue);
	
	//Close everything
	Housekeeping();

}

//This is a function that generates a waitForUser dialog with waitForUserDialog 
//that then retrieves a checkbox value with the string checkboxString so that 
//the user can check an image and then return feedback for a given string
function userApproval(waitForUserDialog, dialogName, checkboxString) {

	//We zoom into an image 3 times so that its bigger on the screen for the user 
	//to check
	for(i=0; i<3; i++) {
		run("In [+]");
	}

	//Scale the image to fit, before exiting and displaying hidden images from 
	//batch mode, autocontrasting the image, then waiting for the user				
	run("Scale to Fit");					
	setBatchMode("Show");
	setOption("AutoContrast", true);
	waitForUser(waitForUserDialog);

	//Once exiting the wait for user dialog we ask the user to give feedback 
	//through a dialog box and then return the checkbox boolean value						
	Dialog.create(dialogName);
	Dialog.addCheckbox(checkboxString, true);
	Dialog.show();
	output = Dialog.getCheckbox();
	return output;
}

function readAndDisplayCellCoordinates(tableLoc, xColName, yColName, imageID) {

	//Read in columns of X and Y coordinates and then display them as point selections on 
	//the image specified, then show this image
	xPoints = getTableColumn(tableLoc, xColName);
	yPoints = getTableColumn(tableLoc, yColName);

	selectImage(imageID);
	makeSelection("point circle cyan extra large", xPoints, yPoints);
	setBatchMode("show");

	return selectionType;
}

function openDisplayAndApproveCoordinates(imageLoc, tableLoc) {
				
	//Open our image
	open(imageLoc);
	if(is("Inverting LUT")==true) {
		run("Invert LUT");
	}

	//Display the detected cell coordinates for this image
	projectOn = getImageID();
	areThereCoordinates = readAndDisplayCellCoordinates(tableLoc, 'X', 'Y', projectOn);

	//If there are cell ROIs generated
	if(areThereCoordinates != -1) {

		//Ask the user whether these automated masks were generated well or not
		goodCPs = userApproval("Check that the automated CP selection has worked", "CP Checking", "Automated CPs Acceptable?");

	} else {
		goodCPs = false;
	}

	//Rename our image with the projection to whatever it is we're renaming to
	selectImage(projectOn);
	rename('coordImage');

	return goodCPs;
}

function getBadCPReasons() {

	//Ask the user to check what was wrong with the image and get whether it was bad registration,
	//bad detection, or both
	waitForUser("Check whats wrong with automated CP generation \nBad registration of the image? Bad detection of cells? \nWhen you've decided, click 'ok'");
	Dialog.create("What went wrong?");
	Dialog.addCheckbox("Bad registration?", false);
	Dialog.addCheckbox("Bad detection?", false);
	Dialog.show();
	badRegRaw = Dialog.getCheckbox();
	badDetectionRaw = Dialog.getCheckbox();		

	return newArray(badRegRaw, badDetectionRaw);

}

function userSelectCells(message) {
					
	//Set the tool to multipoint and ask the user to click on any cells the
	//automatic placement generation missed
	setTool("multipoint");
	selectWindow('coordImage');
	//roiManager("Show All");
	waitForUser(message);

	selectCells = selectionType;

	return selectCells;

}

function addSelectedCoordinateStoExisting(tableLoc) {

	//Get the coordinates of our existing selection
	getSelectionCoordinates(newX, newY);

	//If we have a coordinates table previously made
	if(File.exists(tableLoc) == 1) {

		//Get the existing coordinates
		existingX = getTableColumn(tableLoc, 'X');
		existingY = getTableColumn(tableLoc, 'Y');

		//Concatenate the two - the original X and Y coords and the ones we've added
		newX = Array.concat(newX, existingX);
		newY = Array.concat(newY, existingY);

		//Make sure our table is open at the end
		open(tableLoc);
	
	//If we haven't created a coordinate table, make it	
	} else {
		Table.create(File.getName(tableLoc));
	}

	//Set our columns to our coordinates
	selectWindow(File.getName(tableLoc));
	Table.setColumn("X", newX);
	Table.setColumn("Y", newY);

	//Create our 'optimum' coordinate columns as placeholders (we fill these values in the next module)
	//with values of -1
	xOpt = Array.copy(newX);
	Array.fill(xOpt, -1);
	yOpt = Array.copy(newY);
	Array.fill(yOpt, -1);

	Table.setColumn("xOpt", xOpt);
	Table.setColumn("yOpt", yOpt);

	//Likewise this is also a placeholder
	optimalThreshold = Array.copy(newX);
	Array.fill(optimalThreshold, -1);
	Table.setColumn("Optimal Threshold", optimalThreshold);

	Table.save(tableLoc);
	toClose = Table.title();
	selectWindow(toClose);
	run("Close");

}

//This function clears the results table if it exists, clears the roimanager, and closes 
//all open images - useful for quickly clearing the workspace
function Housekeeping() {
	
	if (isOpen("Results")) {
		run("Clear Results");
	}
	if(roiManager("count")>0) {
		roiManager("deselect");
		roiManager("delete");
	}
	if(nImages>0) {
		run("Close All");
	}
}

function makeCellDetectionFolders(storageFolders, directories, imageNameRaw) {
	
	//Create our storage folders if they don't already exist
	toMake = newArray(storageFolders.length);
	for(currFolder = 0; currFolder < storageFolders.length; currFolder++) {
		toMake[currFolder] = directories[1] + imageNameRaw + "/" + storageFolders[currFolder];
	}
	makeDirectories(toMake);
}

setBatchMode(true);

//These folder names are where we store various outputs from the processing 
//(that we don't need for preprocessing)
storageFolders=newArray("Cell Coordinates/", "Cell Coordinate Masks/",
    "Somas/", "Local Regions/");

//Get user input into where our working directory, and image storage directories, reside
directories = getWorkingAndStorageDirectories();
//[0] is input, [1] is output, [2] is done (working directories) [3] is directoryName (storage directory)

//Ask the user what size buffer in um to use to seperate substacks; defaults to 10					
Dialog.create('Buffer Size');
Dialog.addNumber('What size buffer in um to use to seperate substacks?', 10);
Dialog.show();
zBuffer = Dialog.getNumber();

//Populate our image info arrays
imagesToUseFile = directories[1] + "Images to Use.csv";

if(File.exists(imagesToUseFile) != 1) {
	exit("Need to run the stack preprocessing and stack QA steps first");
}

//If we already have a table get out our existing status indicators
imageName = getTableColumn(imagesToUseFile, "Image Name");
autoPassedQA = getTableColumn(imagesToUseFile, "Auto QA Passed");
manualPassedQA = getTableColumn(imagesToUseFile, "Manual QA Passed");

//This is an array with the strings that come just before the information we want to retrieve from the ini file.
iniTextStringsPre = newArray("x.pixel.sz = ", "y.pixel.sz = ", "z.spacing = ", "no.of.planes = ", "frames.per.plane = ");

//Array to store the values we need to calibrate our image with
iniValues =  getIniData(directories[3], iniTextStringsPre);
//Index 0 is xPxlSz, then yPxlSz, zPxlSz, ZperT, FperZ

//Point to the table where we store the status of our images in the processing pipeline
maskGenerationStatusLoc = directories[1] +  "Mask Generation Status.csv";

//If a file declaring the status of all our images re: mask generation exists, get the image names
//else make the array based on inputs
if(File.exists(maskGenerationStatusLoc) == 1) {

	//Retrieve our existing columns
	imageNameMasks = getTableColumn(maskGenerationStatusLoc, "Image Name");

//If we don't have the file, we haven't run this yet
} else {

	//Set our arrays to their default values
	imageNameMasks = imageName;

}

//Retrieve the number of substacks to be made for each image, as well as the number we've already made - if the file doesn't
//exist, set these defaults to -1 (not calculated) and 0
substacksPossible = getOrCreateTableColumn(maskGenerationStatusLoc, "Number of Substacks to Make", -1, imageName.length);
substacksMade = getOrCreateTableColumn(maskGenerationStatusLoc, "Number of Substacks Made", 0, imageName.length);

//For each image we're processing
for(currImage = 0; currImage < imageName.length; currImage++) {

	//Calculate if we're to detect cells for it - e.g. if it has passed QA, and we haven't made all the substacks for it
	proceedCellDetection = proceedWithCellDetection(autoPassedQA, manualPassedQA, substacksMade, substacksPossible);

	if(proceedCellDetection == true) {

		print('Automatically detecting cell locations for:');
		print(imageName[currImage]);

		//Calculate the number of substacks we can make for this image
		substacksPossible[currImage] = getNoSubstacks(substacksPossible[currImage], iniValues, zBuffer);

		print('Number of substacks we can extract from stack:');
		print(substacksPossible[currImage]);

		//Create an array storing the beginning and ending slices for each substack we're making
		maskGenerationArray = getSlicesForEachSubstack(substacksPossible[currImage], zBuffer);

		//Here we make any storage folders that aren't related to TCS and 
		//haven't already been made
		imageNameRaw = File.getNameWithoutExtension(imageName[currImage]);
		makeCellDetectionFolders(storageFolders, directories, imageNameRaw);

		//For our cell position marking table, get out our columns for this image - unless they don't exist in which case make
		//them with defaults of -1
		cellPositionMarkingLoc = directories[1] + imageNameRaw + "/Cell Coordinate Masks/Cell Position Marking.csv";

		processed = getOrCreateTableColumn(cellPositionMarkingLoc, "Processed", -1, substacksPossible[currImage]);
		qcValue = getOrCreateTableColumn(cellPositionMarkingLoc, "QC", -1, substacksPossible[currImage]);

		//If the table is new, fill the substackNames array with our maskGenerationArray values
		if(File.exists(cellPositionMarkingLoc)!=1) {
			substackNames = Array.copy(maskGenerationArray);
		} else {
			substackNames = getTableColumn(cellPositionMarkingLoc, "Substack");
		}

		//For each substack we're making for this image
		for(currSubstack = 0; currSubstack < substacksPossible[currImage]; currSubstack++) {

			//If that substack hasn't been processed / made
			if(processed[currSubstack] == -1) {

				print('Detecting and saving cells for substack:');
				print(maskGenerationArray[currSubstack]);

				detectSubstackCellsSaveSubstackImages(directories, imageNameRaw, maskGenerationArray[currSubstack]);

				//Set our processed value for this substack to 1, and our substacksMade value for this image to whatever it was + 1
				processed[currSubstack] = 1;
				substacksMade[currImage] = substacksMade[currImage] + 1;

				//Save our substack and image specific tables
				saveSubstackStatusTable(substackNames, processed, qcValue, cellPositionMarkingLoc);
				saveMaskGenerationStatusTable(imageNameMasks, substacksPossible, substacksMade, maskGenerationStatusLoc);

			}
		}

		print('Processing of substacks for', imageName[currImage], ' complete');
	}

}

print('Automated cell detection complete');

//Retrieve the number of substacks to be made for each image, as well as the number we've already made - if the file doesn't
//exist, set these defaults to -1 (not calculated) and 0
substacksPossible = getOrCreateTableColumn(maskGenerationStatusLoc, "Number of Substacks to Make", -1, imageName.length);
substacksMade = getOrCreateTableColumn(maskGenerationStatusLoc, "Number of Substacks Made", 0, imageName.length);

//For each image we're processing
for(currImage = 0; currImage < imageName.length; currImage++) {

	//Here we make any storage folders that aren't related to TCS and 
	//haven't already been made
	imageNameRaw = File.getNameWithoutExtension(imageName[currImage]);

	//For our cell position marking table, get out our columns for this image - unless they don't exist in which case make
	//them with defaults of -1
	cellPositionMarkingLoc = directories[1] + imageNameRaw + "/Cell Coordinate Masks/Cell Position Marking.csv";

	processed = getOrCreateTableColumn(cellPositionMarkingLoc, "Processed", -1, substacksPossible[currImage]);
	qcValue = getOrCreateTableColumn(cellPositionMarkingLoc, "QC", -1, substacksPossible[currImage]);

	//If the table is new, fill the substackNames array with our maskGenerationArray values
	if(File.exists(cellPositionMarkingLoc)!=1) {
		exit("Error - no Cell Position Marking.csv file for this image even though we're passed the cell detection stage")
	} else {
		substackNames = getTableColumn(cellPositionMarkingLoc, "Substack");
	}

	//For each substack for this image
	for(currSubstack = 0; currSubstack < substackNames.length; currSubstack++) {

		//If we've made this substack already but haven't quality controlled the cell selection
		if(processed[currSubstack] == 1 && qcValue[currSubstack] == -1) {

			print('Quality controlling cell detection for:');
			print(imageName[currImage], ' substack ', substackNames[currSubstack]);

			imageLoc = directories[1]+imageNameRaw+"/Cell Coordinate Masks/CP mask for Substack ("+substackNames[currSubstack]+").tif";
			tableLoc = directories[1]+imageNameRaw+"/Cell Coordinates/CP coordinates for Substack ("+substackNames[currSubstack]+").csv";

			//Open the image and display the detected cell coordinates on it
			goodCPs = openDisplayAndApproveCoordinates(imageLoc, tableLoc);

			//If the user isn't happy with the detection
			if(goodCPs == false) {

				print('User unhappy with automated cell detection');

				//Ask why - detection or registration>
				reasonsArray = getBadCPReasons();
				badReg = reasonsArray[0];
				badDetection = reasonsArray[1];

				//If it's just detection
				if(badDetection == 1 && badReg == 0) {

					print('Automated cell detection was poor; prompting user to select cells manually');

					//Ask the user to select cells on the image
					run("Select None");
					selectedCells = userSelectCells("Click on cells to select for analysis, if any, and click 'ok' when done");
					
					//If they\ve selected cells, save them to our substack table and set QC to 1
					if(selectedCells != -1) {
						print('User-selected cells being saved to coordinates file');
						deleted = File.delete(tableLoc);
						if(deleted != 1) {
							exit("Issue with deleting coordinates file");
						}
						addSelectedCoordinateStoExisting(tableLoc);
						qcValue[currSubstack] = 1;

					//If the user didn't select any cells, set QC to 0 (for failing QC)
					} else {
						qcValue[currSubstack] = 0;
						print("No cells selected for this substack");
						print('This substack will be ignored for future steps');

					}

				}

				//If the user selected that the image was badly registered
				if(badReg == 1) {

					print('User indicated stack was poorly registered; ignoring for future analysis steps');

					//Set QC to 0 for a fail
					qcValue[currSubstack] = 0;
					//Do something here? Move it back to input and flag for manual?
				}

			//If the user is happy with the automated cell selection
			} else {

				print('User happy with automated cell detection');
				print('Prompting user to select any additional cells that were missed by automated selection');

				//Set qc to 1 to show we passed
				qcValue[currSubstack] = 1;

				//Ask the user to select any additional cells they missed
				roiManager("add")
				setOption("Show All", true);
				selectedCells = userSelectCells("Click on cells that were missed by automatic detection, if any, and click 'ok' when done");
				
				//If the user clicked on additional cells
				if(selectedCells !=-1) {

					print('Adding user selected cells to coordinate file');
					//Since the talbe at tableLoc already exists, we update it
					addSelectedCoordinateStoExisting(tableLoc);

				}

			}

			saveSubstackStatusTable(substackNames, processed, qcValue, cellPositionMarkingLoc);

			Housekeeping();


		}

	}

	print('Quality control of cell detection for ', imageName[currImage], ' complete');

}

print('QC of cell detection complete');