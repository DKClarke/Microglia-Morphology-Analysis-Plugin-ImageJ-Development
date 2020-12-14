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
	if(File.exists(tableLoc) == 1) {
		outputArray = getTableColumn(tableLoc, columnName);
	} else {
		outputArray = newArray(defaultLength);
		Array.fill(outputArray, defaultValue);
	}

	return outputArray;
}

function proceedWithCellDetection(autoPassedQA, manualPassedQA, substacksMade, substacksPossible) {

	proceed = false;

	passedQA = false;
	if(autoPassedQA[currImage] == 1 || manualPassedQA[currImage] == 1) {
		passedQA = true;
	}

	madeAllSubstacks = true;
	if(substacksMade[currImage] == 0 || (substacksPossible[currImage] == substacksMade[currImage])){
		madeAllSubstacks = false;
	}

	if(passedQA == true && madeAllSubstacks == false) {
		proceed = true;
	}

	return proceed;

}

function getNoSubstacks(imageName, directories, substacksPossible, iniValues, preProcStringToFind, zBuffer) {
			
	//If the image was kept, count how many 10um thick substacks we can make with at least
	//10um spacing between them, and 10um from the bottom and top of the stack
	imageNameRaw = File.getNameWithoutExtesion(imageName);
	imagePath = directories[1]+imageNameRaw+"/"+imageNameRaw+" processed.tif";

	if(substacksPossible == -1) {

		timepoints = openAndGetImageTimepoints(imagePath, iniValues, 'Morphology');
		selectWindow(File.getName(filePath));
		run("Close");
		
		//Calculate how much Z depth there is in the stack
		zSize = iniValues[3] * timepoints * iniValues[2];

		//Calculate how many 10um thick substacks we can make from this stack, including a user defined buffer size
		//between substacks
		noSubstacks = floor(zSize / (zBuffer+10));

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

function combineResultsCols(colNames) {
	selectWindow("Results");
	numbResults = nResults;
	firstArray = newArray(1);
	firstArray[0] = numbResults;
	for(currCol = 0; currCol < colNames.length; currCol++) {
		if(currCol == 0) {
			outputArray = Array.concat(firstArray, Table.getColumn(colNames[currCol]));
		} else {
			outputArray = Array.concat(outputArray, Table.getColumn(colNames[currCol]));
		}
	}
	run("Close");

	return outputArray;
}

function getMaximaCoordinates(imagePath, currMaskGenerationArray, columnNames) {
	//Open the processed image, make a substack, max project it
	open(imagePath);
	if(is("Inverting LUT")==true) {
		run("Invert LUT");
	}

	rename('Raw');
	run("Make Substack...", " slices="+currMaskGenerationArray+"");
	selectWindow('Raw');
	run("Z Project...", "projection=[Average Intensity]");
	selectWindow("AVG_"+'Raw');
	rename("AVG");
				
	//We use a max projection of the chunk to look for our cells, and we 
	//set its calibration to pixels so that the coordinates we retrieve 
	//are accurate as imageJ when plotting points plots them according 
	//to pixel coordinates
	getDimensions(width, height, channels, slices, frames);
	run("Properties...", "channels="+channels+" slices="+slices+" frames="+frames+" unit=pixels pixel_width=1 pixel_height=1 voxel_depth=1.0000000");
	run("8-bit");
	run("Clear Results");
		
	//We look for cells using the fina maxima function and ouput a list
	//of the maxima and save these as coordinates
	run("Find Maxima...", "noise=50 output=[Maxima Within Tolerance] exclude");
	if(is("Inverting LUT")==true) {
		run("Invert LUT");
	}
	selectWindow("AVG");
	run("Find Maxima...", "noise=50 output=List exclude");

	outputArray = combineResultsCols(columnNames);

	return outputArray;

}

function saveSubstackStatusTable(substackNames, badReg, badDetection, processed, qcValue, saveLoc) {
	//Save these arrays into a table
	Table.create("Cell Position Marking.csv");
	Table.setColumn("Substack", substackNames);
	Table.setColumn("Bad Registration", badReg);
	Table.setColumn("Bad Detection", badDetection);
	Table.setColumn("Processed", processed);
	Table.setColumn("QC", qcValue);
	Table.save(saveLoc);
	selectWindow("Cell Position Marking.csv");
	run("Close");
}

function saveMaskGenerationStatusTable(imageNameMasks, substacksPossible, substacksMade, saveLoc) {
	//Save these arrays into a table
	Table.create("Mask Generation Status.csv");
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
	} else {
		Table.setColumn("X", newX);
		Table.setColumn("Y", newY);
	}

	//Save this table
	saveAs("Results", directories[1]+imageNameRaw+"/Cell Coordinates/CP coordinates for Substack (" + currentMaskGen + ").csv");
	Table.close();

}

function saveMaximaImages(directories, imageNameRaw, currMaskGen) {
	//Save the images we used to generate these maxima
	selectWindow("AVG Maxima");
	run("Select None");
	saveAs("tiff", directories[1] + imageNameRaw + "/Cell Coordinate Masks/Automated CPs for Substack (" + currMaskGen + ").tif");
	selectWindow("AVG");
	run("Select None");
	saveAs("tiff", directories[1] + imageNameRaw + "/Cell Coordinate Masks/CP mask for Substack (" + currMaskGen + ").tif");
	close("*");
}

function detectSubstackCellsSaveSubstackImages(directories, imageNameRaw, maskGenerationValue) {

	//Retrieve the coordinates in x and y of the maxima in the average projection of the image
	imagePath = directories[1] + imageNameRaw + "/" + imageNameRaw +" processed.tif";
	columnNames = newArray('X', 'Y');
	unformattedLocations = getMaximaCoordinates(imagePath, maskGenerationValue, columnNames);

	cutIndex = unformattedLocations[0]+1
	newX = Array.slice(unformattedLocations, 1, cutIndex);
	newY = Array.slice(unformattedLocations, cutIndex);

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
	setBatchMode("Exit and Display");
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

function readAndDisplayCellCoordinates(tableLoc, xColName, yColName, image) {

	xPoints = getTableColumn(tableLoc, xColName);
	yPoints = getTableColumn(tableLoc, yColName);

	selectImage(imageID);
	makeSelection("point", xPoints, yPoints);
	setBatchMode("show");

	return selectionType();
}

function openDisplayAndApproveCoordinates(imageLoc, tableLoc, renameTo) {
				
	//Open its cell placement masks image and the image that has the automated CPs
	open(directories[1]+imageNameRaw"/Cell Coordinate Masks/CP mask for Substack ("+substackNames[currSubstack]+").tif");
	if(is("Inverting LUT")==true) {
		run("Invert LUT");
	}

	projectOn = getImageID();
	areThereCoordinates = readAndDisplayCellCoordinates(tableLoc, 'X', 'Y', projectOn);

	//If there are cell ROIs generated
	if(areThereCoordinates != -1) {
		roiManager("add");
		selectImage(projectOn);
		roiManager("select", 0);

		//Ask the user whether these automated masks were generated well or not
		goodCPs = userApproval("Check that the automated CP selection has worked", "CP Checking", "Automated CPs Acceptable?");

	} else {
		goodCPs = false;
	}

	selectImage(projectOn);
	rename(renameTo);

	return goodCPs;
}

function getBadCPReasons() {

	//Ask the user to check what was wrong with the image and get whether it was bad registration,
	//bad detection, or both
	//run("Tile");
	waitForUser("Check whats wrong with automated CP generation");

	Dialog.create("What went wrong?");
	Dialog.addCheckbox("Bad registration?", false);
	Dialog.addCheckbox("Bad detection?", false);
	Dialog.show();
	badRegRaw = Dialog.getCheckbox();
	badDetectionRaw = Dialog.getCheckbox();		

	return newArray(badRegRaw, badDetectionRaw);

}

function userSelectMissedCells(renameTo) {
					
	//Set the tool to multipoint and ask the user to click on any cells the
	//automatic placement generation missed
	setTool("multipoint");
	selectWindow(renameTo);
	roiManager("Show All");
	waitForUser("Click on cells that were missed by automatic detection, if any");

	selectCells = selectionType();

	return selectCells;

}

function getSelectionCoordinates() {

	//Add the cell locations to the roiManager and measure them to get their X,Y coords
	//in the results window
	roiManager("add");
	run("Set Measurements...", "centroid redirect=None decimal=0");
	run("Clear Results");
	roiManager("Select", 1);
	roiManager("Measure");
	
	setBatchMode(true);
	
	outputArray = combineResultsCols(newArray('X', 'Y'));

	return outputArray;

}

function addSelectedCoordinateStoExisting(tableLoc) {

	outputArray = getSelectionCoordinates();
	
	cutIndex = outputArray[0]+1
	selectedX = Array.slice(outputArray, 1, cutIndex);
	selectedY = Array.slice(outputArray, cutIndex);

	existingX = getTableColumn(tableLoc, 'X');
	existingY = getTableColumn(tableLoc, 'Y');

	//Concatenate the two - the original X and Y coords and the ones we've added
	newX = Array.concat(selectedX, existingX);
	newY = Array.concat(selectedY, existingY);

	Table.read(tableLoc);
	Table.setColumn("X", newX);
	Table.setColumn("Y", newY);
	Table.save(tableLoc);
	toClose = Table.title();
	selectWindow(toClose);
	run("Close");

}

//These folder names are where we store various outputs from the processing 
//(that we don't need for preprocessing)
storageFolders=newArray("Cell Coordinates/", "Cell Coordinate Masks/",
    "Somas/", "Candidate Cell Masks/", "Local Regions/", "Results/");

//Set the size of the square to be drawn around each cell in um
LRSize = 120;

//Get user input into where our working directory, and image storage directories, reside
directories = getWorkingAndStorageDirectories();
//[0] is input, [1] is output, [2] is done (working directories) [3] is directoryName (storage directory)

//Populate our image info arrays
tableLoc = directories[1] + "Images to Use.csv";

if(File.exists(tableLoc) != 1) {
	exit("Need to run the stack preprocessing step first");
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

		//Calculate the number of substacks we can make for this image
		subStacksPossible[currImage] = getNoSubstacks(imageName[currImage], directories, substacksPossible[currImage], iniValues, 'Morphology', zBuffer);

		//Create an array storing the beginning and ending slices for each substack we're making
		maskGenerationArray = getSlicesForEachSubstack(substacksPossible[currImage], zBuffer);

		//Here we make any storage folders that aren't related to TCS and 
		//haven't already been made
		imageNameRaw = File.getNameWithoutExtension(imageName[currImage]);
		makeCellDetectionFolders(storageFolders, directories, imageNameRaw));

		//For our cell position marking table, get out our columns for this image - unless they don't exist in which case make
		//them with defaults of -1
		cellPositionMarkingLoc = directories[1] + imageNameRaw + "/Cell Coordinate Masks/Cell Position Marking.csv";

		badReg = getOrCreateTableColumn(cellPositionMarkingLoc, "Bad Registration", -1, substacksPossible[currImage]);
		badDetection = getOrCreateTableColumn(cellPositionMarkingLoc, "Bad Detection", -1, substacksPossible[currImage]);
		processed = getOrCreateTableColumn(cellPositionMarkingLoc, "Processed", -1, substacksPossible[currImage]);
		qcValue = getOrCreateTableColumn(cellPositionMarkingLoc, "QC", -1, substacksPossible[currImage]);

		//If the table is new, fill the substackNames array with our maskGenerationArray values
		if(File.exists(cellPositionMarkingLoc)!=1) {
			substackNames = Array.copy(maskGenerationArray);
		} else {
			substackNames = getTableColumn(cellPositionMarkingLoc, Substack);
		}

		//For each substack we're making for this image
		for(currSubstack = 0; currSubstack < substacksPossible[currImage]; currSubstack++) {

			//If that substack hasn't been processed / made
			if(processed[currSubstack] == -1) {

				detectSubstackCellsSaveSubstackImages(directories, imageNameRaw, maskGenerationArray[currSubstack]);

				//Set our processed value for this substack to 1, and our substacksMade value for this image to whatever it was + 1
				processed[currSubstack] = 1;
				substacksMade[currImage] = substacksMade[currImage] + 1;

				//Save our substack and image specific tables
				saveSubstackStatusTable(substackNames, badReg, badDetection, processed, qcValue, cellPositionMarkingLoc);
				saveMaskGenerationStatusTable(imageNameMasks, substacksPossible, substacksMade, maskGenerationStatusLoc);

			}
		}
	}
}

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

	badReg = getOrCreateTableColumn(cellPositionMarkingLoc, "Bad Registration", -1, substacksPossible[currImage]);
	badDetection = getOrCreateTableColumn(cellPositionMarkingLoc, "Bad Detection", -1, substacksPossible[currImage]);
	processed = getOrCreateTableColumn(cellPositionMarkingLoc, "Processed", -1, substacksPossible[currImage]);
	qcValue = getOrCreateTableColumn(cellPositionMarkingLoc, "QC", -1, substacksPossible[currImage]);

	//If the table is new, fill the substackNames array with our maskGenerationArray values
	if(File.exists(cellPositionMarkingLoc)!=1) {
		exit("Error - no Cell Position Marking.csv file for this image even though we're passed the cell detection stage")
	} else {
		substackNames = getTableColumn(cellPositionMarkingLoc, Substack);
	}

	for(currSubstack = 0; currSubstack < substackNames.length; currSubstack++) {

		if(processed[currSubstack] == 1 & qcValue == -1) {

			imageLoc = directories[1]+imageNameRaw"/Cell Coordinate Masks/CP mask for Substack ("+substackNames[currSubstack]+").tif";
			tableLoc = directories[1]+imageNameRaw+"/Cell Coordinates/CP coordinates for Substack ("+substackNames[currSubstack]+").csv";
			renameTo = 'coordImage'

			goodCPs = openDisplayAndApproveCoordinates(imageLoc, tableLoc, renameTo);

			if(goodCPs = false) {

				reasonsArray = getBadCPReasons();
				badReg = reasonsArray[0];
				badDetection = reasonsArray[1];


				//This is hte next thing we need to clean up
				if(badDetection == 1 && badReg == 0) {
					
					//Delete the automatically generated masks overlay
					if(roiManager("count")>0) {
						roiManager("deselect");
						roiManager("delete");
					}
					selectWindow("MAX");
					
					//Ask the user to click on cell bodies
					setTool("multipoint");
					setBatchMode("Exit and Display");
					roiManager("show none");
					run("Select None");
					waitForUser("Click on cell bodies to select cells for analysis");
					setBatchMode(true);
					
					//Once the user has selected all the cells, we add them to roiManager before measuring them with roiManager to get their coordinates
					roiManager("add");
					run("Set Measurements...", "centroid redirect=None decimal=0");
					selectWindow("MAX");
					roiManager("Select", 0);
					run("Clear Results");
					roiManager("Measure");
					roiManager("delete");

					//Save the coordinates of cell placements
					selectWindow("Results");
					saveAs("Results", directories[1]+imageNames[3]+"/Cell Coordinates/CP coordinates for " + imgName + ".csv");

					//Set bad detection 0
					badDetection = 0;

				}

			} else {

				selectedCells = userSelectMissedCells(renameTo);
				
				//If the user clicked on additional cells
				if(selectedCells !=-1) {

					addSelectedCoordinateStoExisting(tableLoc);

				}

			}

			Houekeeping();


		}

	}


			
							//If the current substack hasn't been quality controleld
							if(currentQC==0) {
				
								//If the image had bad detection but otherwise the registration was fine
								if(badDetection == 1 && badReg == 0) {
				
								//If the image had bad registration, we do nothing
								} else {
									setBatchMode(true);
								}
	
								//Future - write code so that if the image had bad registration we can rbound to manually register it
								//Or just get out a list of bad reg so its not automated?
								
								//Set currentQC to 1 since we've finished quality control
								currentQC = 1;
				
								//Update our cell position marking table and save it
								selectWindow("Cell Position Marking");
								Table.set("Bad Detection", i0, badDetection);
								Table.set("Bad Registration", i0, badReg);
								Table.set("QC", i0, currentQC);
								Table.update;
								Table.save(directories[1] + imageNames[3] + "/Cell Coordinate Masks/Cell Position Marking.csv"); 
				
								Housekeeping();
							
							}
						}
			
					Table.reset("Cell Position Marking");
		
					}
				}
			}
		}
	}