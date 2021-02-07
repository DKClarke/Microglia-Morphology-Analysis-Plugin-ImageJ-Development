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

function getCellMaskApproval(cellMaskLoc, cellLRLoc) {

	//Open this TCS's version of the mask
	open(cellMaskLoc);
	selectWindow(File.getName(cellMaskLoc));
	run("Select None");
	
	//Create a selection from the mask
	run("Create Selection");
	getSelectionCoordinates(xpoints, ypoints);

	//Open the LR associated with this mask and apply the selection
	open(cellLRLoc);
	selectWindow(File.getName(cellLRLoc));
	run("Select None");
	makeSelection('freehand', xpoints, ypoints);

	setBatchMode("Show");
	approved = userApproval("Check image for issues", "Mask check", "Keep the image?");

	return approved;

}

function generateCellSomaMask(cellMaskLoc, cellLRLoc) {

	//Select the cell mask
	selectWindow(File.getName(cellMaskLoc));
	run("Select None");
	
	//Create a selection from the mask
	run("Create Selection");
	getSelectionCoordinates(xpoints, ypoints);

	//Apply some image functions to the cell from the LR image to generate a soma mask
	selectWindow(File.getName(cellLRLoc));
	run("Select None");
	run("Duplicate...", " ");
	rename("Soma Mask");
	selectWindow("Soma Mask");
	makeSelection('freehand', xpoints, ypoints);
	run("Clear Outside");
	run("Select None");
	run("Auto Threshold", "method=Intermodes  white");
	logString = getInfo("log");
	intermodesIndex = lastIndexOf(logString, "Intermodes");

	//This is if there is an issue with the auto thresholding so we avoid an error
	if(intermodesIndex!=-1) {
		print("Intermodes didn't work");
		run("Auto Threshold", "method=Otsu  white");
		selectWindow("Log");
		run("Close");
	}
	
	run("Open");
	run("Watershed");

	for(i1=0; i1<3; i1++) {
		run("Erode");
	}

	for(i1=0; i1<2; i1++) {
		run("Dilate");
	}
	
	run("Invert");

	//Here we check how many particles have been left after this process
	run("Auto Threshold", "method=Default");
	run("Clear Results");
	run("Analyze Particles...", "size=30-Infinity circularity=0.60-1.00 show=Masks display clear");
	getStatistics(area, mean, min, max, std, histogram);
	
	if(getResult("Area", 0) == area) {
		adjustedN = nResults - 1;
	} else {
		adjustedN = nResults;
	}

	return adjustedN;

}

setBatchMode(true);

//Get user input into where our working directory, and image storage directories, reside
directories = getWorkingAndStorageDirectories();
//[0] is input, [1] is output, [2] is done (working directories) [3] is directoryName (storage directory)

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
	
	print("QA'ing masks generated for image ",File.getNameWithoutExtension(imageName[currImage]));

	imageNameRaw = File.getNameWithoutExtension(imageName[currImage]);

	statusTable = directories[1]+imageNameRaw+"/Cell Coordinate Masks/Cell Position Marking.csv";

	if(File.exists(statusTable) != 1) {
		exit("Run cell detection first");
	}

	substackNames = substacksToUse(statusTable, 'Substack', 'Processed', 'QC');

	for(currSubstack = 0; currSubstack < substackNames.length; currSubstack++) {

		print("Processing substack ", substackNames[currSubstack]);

        tcsStatusTable = directories[1]+imageNameRaw+"/TCS Status Substack(" + substackNames[currSubstack] +").csv";
        
        if(File.exists(tcsStatusTable) != 1) {
            exit("Run mask generation first");
        }

		tcsValue = getTableColumn(tcsStatusTable, "TCS");
		tcsMasksGenerated = getTableColumn(tcsStatusTable, "Masks Generated");
		tcsQCChecked = getTableColumn(tcsStatusTable, "QC Checked");
		tcsAnalysed = getTableColumn(tcsStatusTable, "Analysed");

		for(TCSLoops=0; TCSLoops<tcsValue.length; TCSLoops++) {

			if(tcsQCChecked[TCSLoops] == -1) {

				print("QA'ing masks for TCS value of ", tcsValue[TCSLoops]);

				//This is the directory for the current TCS
				TCSDir=directories[1]+imageNameRaw+"/"+"TCS"+tcsValue[TCSLoops]+"/";
				TCSMasks = TCSDir + "Cell Masks/";

                cellMaskTable = TCSDir + "Substack (" + substackNames[currSubstack] + ") Mask Generation.csv";
                
                if(File.exists(cellMaskTable) != 1) {
                    exit("Run mask generation first");
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

                    if(maskSuccess[currCell] == 1 && maskQA[currCell] == -1) {
			
                        print("QC for: ", maskName[currCell]);
						print("Cell no.: ", currCell+1, " / ", maskName.length);

						cellMaskLoc = TCSDir + "Cell Masks/" + maskName[currCell];
						approved = getCellMaskApproval(cellMaskLoc, cellLRLoc);

						if(approved == true) {
							maskQA[currCell] = 1;
						} else {
							maskQA[currCell] = 0;
						}
						
						somaName = directories[1]+imageNameRaw+"/Somas/Soma mask " + substackCoordName;

						if(approved == true && File.exists(somaName) != 1) {

							particles = generateCellSomaMask(cellMaskLoc, cellLRLoc);

							keepSoma = false;

							if(particles == 1) {
								selectWindow("Mask of Soma Mask");
								run("Create Selection");
								run("Make Inverse");
								getSelectionCoordinates(somaXpoints, somaYpoints);
								selectWindow(File.getName(cellLRLoc));
								makeSelection('freehand', somaXpoints, somaYpoints);
								keepSoma = userApproval("Check image soma mask", "Soma check", "Keep the soma mask?");

							}

							if(keepSoma == false) {

								waitForUser("Need to draw manual soma mask");
								selectWindow(File.getName(cellLRLoc));
								run("Select None");
								for(i1=0; i1<3; i1++) {
									run("In [+]");
								}
								run("Scale to Fit");
								setTool("polygon");
								setBatchMode("Show");
								waitForUser("Draw appropriate soma mask, click 'ok' when done");
								getSelectionCoordinates(somaXpoints, somaYpoints);
							}

							selectWindow(File.getName(cellLRLoc));
							makeSelection('freehand', somaXpoints, somaYpoints);
							run("Create Mask");
							selectWindow("Mask");
							rename(File.getName(somaName));
							saveAs("tiff", somaName);

						} else if (File.exists(somaName) == 1) {
							print('Soma mask ', File.getNameWithoutExtension(somaName), ' already exists');
						} else if (approved != true) {
							print('Cell mask ', maskName[currCell], ' rejected');
						}

						close("*");

						saveMaskGenerationTable(maskName, maskTry, maskSuccess, maskQA, maskQuant, cellMaskTable);

					}

				}

				tcsQCChecked[TCSLoops] = 1;

				saveTCSStatusTable(substackNames[currSubstack], tcsValue, tcsMasksGenerated, tcsQCChecked, tcsAnalysed, tcsStatusTable);

			}
		}
	}
}

print('Mask QA Finished');

if(false) {
	{
		{
			{
				{
					{
				
						selectWindow(currentMask);
						run("Invert");
						run("Create Selection");
						roiManager("Add");
						selectWindow(currentMask);
						run("Close");
						
						selectWindow(LRImage);
						roiManager("select", 0);
						roiManager("Show All");
		
						setTool("polygon");
						setBatchMode("Exit and Display");
						waitForUser("Draw around any missing processes, add these to roi manager");
	
						//Here we combine all the traces into a single ROI and use this to create a new mask from the local region
						if((roiManager("count"))>1) {
							roiManager("deselect");
							roiManager("Combine");
							roiManager("deselect");
							roiManager("delete");
							roiManager("add");
						} else {	
							roiManager("deselect");	
						}
							
						run("Select None");
						selectWindow(LRImage);
						roiManager("select", 0);
						run("Clear Outside");
						run("Fill", "slice");
						run("Select None");
						run("Invert");
						run("Auto Threshold", "method=Default");
						run("Invert");
						selectWindow(LRImage);
						saveAs("tiff", storageFoldersArray[3]+maskDirFiles[i0]);
						run("Close");
	
						//This indicates we've traced the image
						currentMaskValues[3]=1;
						
					}
	
					Housekeeping();

				//If we don't need to check the mask, set this to say it has been checked
				} else {
					currentMaskValues[1]=1; 
				}

				//Update and save our TCS analysis table
				selectWindow("QC Checked");
				for(i1=0; i1<tableLabels.length; i1++) {
					if(i1==0) {
						stringValue = currentMaskValues[i1];
						Table.set(tableLabels[i1], i0, stringValue);
					} else {
						Table.set(tableLabels[i1], i0, currentMaskValues[i1]);
					}
				}
					
				Housekeeping();	
			}

			selectWindow("QC Checked");
			Table.save(TCSDir+"QC Checked.csv");
			newName = Table.title;
			Table.rename(newName, "QC Checked");
			Table.reset("QC Checked");
			Table.update;
			print("saved at: ", TCSDir + "QC Checked.csv");
	
			//Here we set that we've finished QC for the particular TCS
			currentLoopValues[2] = 1;

			//Update and save our TCS analysis table
			selectWindow("TCS Status");
			for(i0=0; i0<TCSColumns.length; i0++) {
				Table.set(TCSColumns[i0], TCSLoops, currentLoopValues[i0]);
			}

			Table.update;
			Housekeeping();

		}
			
	}
	
	selectWindow("TCS Status");
	Table.update;
	Table.save(directories[1]+imageNames[3]+"/TCS Status.csv");
	currtitle = Table.title;
	Table.rename(currtitle, "TCS Status");

}