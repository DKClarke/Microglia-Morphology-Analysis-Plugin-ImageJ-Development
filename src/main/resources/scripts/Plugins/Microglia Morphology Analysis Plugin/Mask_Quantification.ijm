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

	} else {
		exit("Substack names column in " + substackTableLoc + " not populated");
	}

	return output;

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

function saveAndCloseImage(Image, saveLoc) {
	
	//Save our image and close it
	selectWindow(Image);
	saveAs("tiff", saveLoc);
	selectWindow(File.getName(saveLoc));
	run("Close");

}

function getSkeletonMeasurements(cellMaskLoc, skelNames) {
	//Retrieve our skeleton measurements, skelNames is the array of skeleton measurements to retrieve

	selectWindow(File.getName(cellMaskLoc));

	//Skeletonise the image then get out the measures associated with the skelNames array from earlier
	run("Duplicate...", " ");
	rename("For Skeleton");
	run("Skeletonize (2D/3D)");
	run("Clear Results");
	run("Analyze Skeleton (2D/3D)", "prune=[shortest branch] calculate");
		
	//If we're getting out length, we measure the number of pixels in the skeleton
	storeValues = newArray(skelNames.length);
	for(currMeasure = 0; currMeasure< skelNames.length; currMeasure++) {
		if(skelNames[currMeasure] != 'SkelArea') {
		storeValues[currMeasure] = getResult(skelNames[currMeasure], 0);
		} else {
			selectWindow("For Skeleton");
			run("Create Selection");
			getStatistics(area);
			storeValues[currMeasure] = area;
			run("Select None");
		}
	}

	run("Clear Results");

	//Close images we don't need anymore
	toClose = newArray("Longest shortest paths", "Tagged skeleton");
	for(closeImage = 0; closeImage< toClose.length; closeImage++) {
		if(isOpen(toClose[closeImage])==1) {
		selectWindow(toClose[closeImage]);
		run("Close");
		}
	}

	return storeValues;
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

function getSimpleMeasurements(cellMaskLoc,simpleValues) {
	//Get out simple measurements of our mask and return the array of results

	//Select our non skeletonised image, get its perim, circul, AR, and area
	selectWindow(File.getName(cellMaskLoc));
	run("Create Selection");
	List.setMeasurements;

	resultsStrings = newArray("Perim.", "Circ.", "AR", "Area");
	currentLoopIndices = newArray(0,3,2,5);

	for(i1=0; i1<resultsStrings.length; i1++) {
		simpleValues[(currentLoopIndices[i1])] = List.getValue(resultsStrings[i1]);
	}

	run("Select None");

	return simpleValues;

}

function getExtremaCoordinates(cellMaskLoc) {
	//Return an array of the coordinates of the extrema of our cellMaskLoc

	//Get the coordinates that define our mask
	selectWindow(File.getName(cellMaskLoc));
	run("Create Selection");
	getSelectionCoordinates(xpoints, ypoints);
	run("Select None");

	//Calculate some statistics on this selection
	Array.getStatistics(xpoints, xMin, xMax, mean, stdDev);
	Array.getStatistics(ypoints, yMin, yMax, mean, stdDev);

	//For our rightmost point, we already have our definixing X value (xMax) but we need to find the y value
	//at the xMax coordinate, so get the mean of any matching y points
	rightmostYArray = getArrayOfMatchingValues(xpoints, xMax, ypoints);
	rightmostY = getRoundedMeanOfArray(rightmostYArray);

	//For leftmost we already have our defining x (xMin) so again, get the mean of matching y points
	leftmostYArray = getArrayOfMatchingValues(xpoints, xMin, ypoints);
	leftmostY = getRoundedMeanOfArray(leftmostYArray);

	//etc.
	topmostXArray = getArrayOfMatchingValues(ypoints, yMin, xpoints);
	topmostX = getRoundedMeanOfArray(topmostXArray);

	bottommostXArray = getArrayOfMatchingValues(ypoints, yMax, xpoints);
	bottommostX = getRoundedMeanOfArray(bottommostXArray);

	xAndYPoints = newArray(xMax, rightmostY, xMin, leftmostY, bottommostX, yMax, topmostX, yMin);
	//[0] and [1] are highest x with y (rightmost), [2] and [3] are lowest x with y (leftmost), 
	//[4] and [5] are x and highest y (bottommost) [6] and [7] are x with lowest y (topmost)

	return xAndYPoints;

}

function getCMToExtremaDistances(cellMaskLoc) {

	//Take our cell mask and calibrate it in pixels so we get the centre of mass in pixels
	selectWindow(File.getName(cellMaskLoc));
	run("Duplicate...", " ");
	rename("Cell Spread");
	run("Properties...", "channels=1 slices=1 frames=1 unit=pixels pixel_width=1 pixel_height=1 voxel_depth=1");
	List.setMeasurements;

	resultsStrings = newArray("XM", "YM");
	centresOfMass = newArray(2);

	for(cmCoord=0; cmCoord<resultsStrings.length; cmCoord++) {
		centresOfMass[cmCoord] = List.getValue(resultsStrings[cmCoord]);
	}

	distances = newArray(4);
	//[0] is distance to the right, [1] is to the left, [2] is the top, [3] is the bottom

	//Make a point on the centre of mass
	makePoint(centresOfMass[0], centresOfMass[1], 'medium red dot add');

	//For each extrema
	for(extrema=0; extrema<4; extrema++) {
		
		//Get the x and y coordinates for that extrema
		xToCheck = xAndYPoints[(extrema*2)];
		yToCheck = xAndYPoints[(extrema*2)+1];

		//Calculate the distance between those points and the centre of mass in pixels
		xDistance = abs(xToCheck-centresOfMass[0]);
		yDistance = abs(yToCheck-centresOfMass[1]);

		//Calculate the hypotenuse of that as the distance from the centre of mass to that extrema and store it
		distances[extrema] = sqrt((pow(xDistance,2) + pow(yDistance,2)));

		//Make a point and a line from the centre of mass to the extrema point
		makePoint(xAndYPoints[(extrema*2)], xAndYPoints[(extrema*2)+1], 'medium red dot add');
		makeLine(centresOfMass[0], centresOfMass[1],  xAndYPoints[(extrema*2)], xAndYPoints[(extrema*2)+1]);
		Roi.setStrokeColor('red');
		run("Add Selection...");
	}

	//Return our array of distances between the centre of mass of our mask and the extrema
	return distances;

}

function getSomaArea(somaName) {
	//Open our soma mask and get it's area

	open(somaName);
	run("Create Selection");
	List.setMeasurements;
	somaArea = List.getValue("Area");
	run("Select None");

	return somaArea;

}

function saveCellParametersTable(columnNames, columnValues, cellParameterTableLoc) {
	//Save our cell parameters table where we write each columnValue to a matching columnName value
							
	Table.create("Cell Parameters.csv");
	selectWindow("Cell Parameters.csv");

	for(currCol = 0; currCol < columnNames.length; currCol++) {
		Table.set(columnNames[currCol], 0, columnValues[currCol]);
	}

	Table.save(cellParameterTableLoc);

	selectWindow("Cell Parameters.csv");
	run("Close");
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

setBatchMode(true);

//Get user input into where our working directory, and image storage directories, reside
directories = getWorkingAndStorageDirectories();
//[0] is input, [1] is output, [2] is done (working directories) [3] is directoryName (storage directory)

//Populate our image info arrays
imagesToUseFile = directories[1] + "Images to Use.csv";

if(File.exists(imagesToUseFile) != 1) {
	exit("Need to run the 'Stack Preprocessing' and 'Stack QA' steps first");
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


//For each image
for (currImage=0; currImage<imageName.length; currImage++) {

	//If it passed QA steps
	if(autoPassedQA[currImage] == 1 || manualPassedQA[currImage] == 1) {
	
		print("Quantifying masks generated for image ",File.getNameWithoutExtension(imageName[currImage]));

		imageNameRaw = File.getNameWithoutExtension(imageName[currImage]);

		statusTable = directories[1]+imageNameRaw+"/Cell Coordinate Masks/Cell Position Marking.csv";

		if(File.exists(statusTable) != 1) {
			exit("Run 'Cell Detection' first");
		}

		//Get the names of our substacks that we can use
		substackNames = substacksToUse(statusTable, 'Substack', 'Processed', 'QC');

		//For each substack
		for(currSubstack = 0; currSubstack < substackNames.length; currSubstack++) {

			print("Processing substack ", substackNames[currSubstack]);

			tcsStatusTable = directories[1]+imageNameRaw+"/TCS Status Substack(" + substackNames[currSubstack] +").csv";
			
			if(File.exists(tcsStatusTable) != 1) {
				exit("Run 'Mask Generation' first");
			}

			//Get our TCS related columns
			tcsValue = getTableColumn(tcsStatusTable, "TCS");
			tcsMasksGenerated = getTableColumn(tcsStatusTable, "Masks Generated");
			tcsQCChecked = getTableColumn(tcsStatusTable, "QC Checked");
			tcsAnalysed = getTableColumn(tcsStatusTable, "Analysed");

			//For all our TCS values
			for(TCSLoops=0; TCSLoops<tcsValue.length; TCSLoops++) {

				//Set the path to where we copy our analysed cells to so we can run a fractal analysis on this folder in 
				//batch at a later timepoint - if this directory doesn't exist, make it
				fracLacPath = directories[1]+"fracLac/";
				fracLacTCSPath = fracLacPath + "TCS"+tcsValue[TCSLoops] + "/";
				makeDirectories(newArray(fracLacPath, fracLacTCSPath));

				//If we haven't finished analysing this TCS value
				if(tcsAnalysed[TCSLoops] == -1) {

					print("Quantifying masks for TCS value of ", tcsValue[TCSLoops]);

					//This is the directory for the current TCS
					TCSDir=directories[1]+imageNameRaw+"/"+"TCS"+tcsValue[TCSLoops]+"/";
					TCSMasks = TCSDir + "Cell Masks/";
					makeDirectories(newArray(TCSDir + "Results/"));

					cellMaskTable = TCSDir + "Substack (" + substackNames[currSubstack] + ") Mask Generation.csv";
					
					if(File.exists(cellMaskTable) != 1) {
						exit("Run 'Mask Generation' first");
					}

					print("Retrieving mask generation status");

					maskName = getTableColumn(cellMaskTable, "Mask Name");
					maskTry = getTableColumn(cellMaskTable, "Mask Try");
					maskSuccess = getTableColumn(cellMaskTable, "Mask Success");
					maskQA = getTableColumn(cellMaskTable, "Mask QA");
					maskQuant = getTableColumn(cellMaskTable, "Mask Quantified");

					//We now loop through all the cells for this given input image
					for(currCell=0; currCell<maskName.length; currCell++) {

						substackCoordName = substring(maskName[currCell], indexOf(maskName[currCell], 'for'));
						cellLRLoc = directories[1]+imageNameRaw+"/Local Regions/" + "Local region " + substackCoordName;

						//If we've made a mask for this cell, and it passed QA, but it hasn't been quantified yet
						if(maskSuccess[currCell] == 1 && maskQA[currCell] == 1 && maskQuant[currCell] == -1) {
				
							print("Quantification for: ", maskName[currCell]);
							print("Cell no.: ", currCell+1, " / ", maskName.length);

							cellMaskLoc = TCSDir + "Cell Masks/" + maskName[currCell];
			
							//simpleParams is a list of the parameters we measure using the normal measurements function in
							//imageJ
							simpleParams = newArray("Perimeter", "Cell Spread", "Eccentricity", 
													"Roundness", "Soma Size", "Mask Size"); 
							simpleValues = newArray(simpleParams.length);

							//skelNames is a list of the parameters we measure on a skeletonised image in imageJ
							skelParams = newArray("# Branches", "# Junctions", "# End-point voxels", "# Junction voxels", 
							"# Slab voxels", "Average Branch Length", "# Triple points", "# Quadruple points", 
							"Maximum Branch Length", "Longest Shortest Path", "SkelArea");

							cellFracLacPath = fracLacTCSPath + maskName[currCell];
								
							//If we haven't already copied the cell to the fracLac folder, do so
							if(File.exists(cellFracLacPath) == 0) {
								File.copy(cellMaskLoc, cellFracLacPath);
							}
								
							//Get out our skeleton values
							open(cellMaskLoc);

							skelValues = getSkeletonMeasurements(cellMaskLoc, skelParams);

							skeletonSaveLoc = TCSDir + "Results/" + 'Skeleton ' + File.getName(cellMaskLoc);
							saveAndCloseImage('For Skeleton', skeletonSaveLoc);

							//Get our simple shape measurements
							simpleValues = getSimpleMeasurements(cellMaskLoc,simpleValues);

							xAndYPoints = getExtremaCoordinates(cellMaskLoc);
							//[0] and [1] are highest x with y (rightmost), [2] and [3] are lowest x with y (leftmost), 
							//[4] and [5] are x and highest y (bottommost) [6] and [7] are x with lowest y (topmost)

							distances = getCMToExtremaDistances(cellMaskLoc);

							cellSpreadSaveLoc = TCSDir + "Results/" + 'Cell Spread ' + File.getName(cellMaskLoc);

							saveAndCloseImage('Cell Spread', cellSpreadSaveLoc);

							//Store the average distance from the centre of mass to the xtremeties
							Array.getStatistics(distances, disMin, disMax, disMean, disStdDev);

							//Convert our average distance from centre of mass to extrema to calibrated units from our image
							//though this assumed a square pixel, this is our cell spread value
							calibratedDisMean = disMean * iniValues[0];
							simpleValues[1] = calibratedDisMean;

							somaName = directories[1]+imageNameRaw+"/Somas/Soma mask " + substackCoordName;
							somaArea = getSomaArea(somaName);
							simpleValues[4] = somaArea;

							selectWindow(File.getName(somaName));
							run("Properties...", "channels=1 slices=1 frames=1 unit=pixels pixel_width=1 pixel_height=1 voxel_depth=1");
							List.setMeasurements;

							resultsStrings = newArray("XM", "YM");
							somaCM = newArray(2);
						
							for(cmCoord=0; cmCoord<resultsStrings.length; cmCoord++) {
								somaCM[cmCoord] = List.getValue(resultsStrings[cmCoord]);
							}
							//𝐴=𝜋𝑟2
							//sqrt(A) = PI * r
							//r = sqrt(A) / PI

							//We then find the centre of mass of the soma, and the radius of the soma (on average)
							//so that we can use the point and the radius to calculate a sholl analysis on the cell masks
							//starting from the edge of the soma
							startradius = 2*(sqrt(somaArea) / PI);
							
							//Mask a point on our image and run our sholl analysis
							selectWindow(File.getName(cellMaskLoc));
							run("Select None");
							makePoint(somaCM[0], somaCM[1]);

							pyFileLocation = getDir("plugins") + 'Scripts/Microglia_Morphology_Analysis_Plugin_Sholl_Analysis_Script.py';
							if(File.exists(pyFileLocation) != 1) {
								exit("Microglia_Morphology_Analysis_Plugin_Sholl_Analysis_Script.py not found in the plugins folder at \n" + getDir("plugins"));
							}
							pythonText = File.openAsString(pyFileLocation); 
							saveShollAs = TCSDir + "/Results/";
							call("ij.plugin.Macro_Runner.runPython", pythonText, "startRad="+startradius+",stepSize="+iniValues[0]+",saveLoc="+saveShollAs+",maskName="+maskName[currCell]+",tcsVal="+tcsValue[TCSLoops]+"");

							selectWindow(File.getName(cellMaskLoc));
							run("Close");

							selectWindow(File.getName(somaName));
							run("Close");

							//Save our values
							simpleValues = Array.concat(maskName[currCell], simpleValues);
							simpleParams = Array.concat('Mask Name', simpleParams);

							columnValues = Array.concat(simpleValues, skelValues);
							columnNames = Array.concat(simpleParams, skelParams);

							cellParameterTableLoc = TCSDir + "/Results/Cell Parameters " + File.getNameWithoutExtension(maskName[currCell]) +".csv";

							//Retrieving the status of each mask we need to generate for the current substack (and TCS)
							print("Saving cell parameters");

							saveCellParametersTable(columnNames, columnValues, cellParameterTableLoc);

							maskQuant[currCell] = 1;

							saveMaskGenerationTable(maskName, maskTry, maskSuccess, maskQA, maskQuant, cellMaskTable);

						}
					}

					tcsAnalysed[TCSLoops] = 1;

					saveTCSStatusTable(substackNames[currSubstack], tcsValue, tcsMasksGenerated, tcsQCChecked, tcsAnalysed, tcsStatusTable);
				}
			}
		}
	}
}

print("Mask quantification finished");