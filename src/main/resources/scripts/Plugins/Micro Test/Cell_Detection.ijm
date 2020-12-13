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

function getMaximaCoordinates(imagePath, currMaskGenerationArray) {
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
	selectWindow("Results");
	numbResults = nResults;
	newX = Table.getColumn("X");
	newY = Table.getColumn("Y");
	run("Close");

	return Array.concat(numbResults, newX, newY);

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
	proceed = proceedWithCellDetection(autoPassedQA, manualPassedQA, substacksMade, substacksPossible);

	if(proceed == true) {

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
				
				//Retrieve the coordinates in x and y of the maxima in the average projection of the image
				imagePath = directories[1] + imageNameRaw + "/" + ImageNameRaw +" processed.tif";
				unformattedLocations = getMaximaCoordinates(imagePath, maskGenerationArray[currSubstack]);

				cutIndex = unformattedLocations[0]+1
				newX = Array.slice(unformattedLocations, 1, cutIndex);
				newY = Array.slice(unformattedLocations, cutIndex);

				//Save our coordinates
				fillAndSaveSubstackCoordinatesTable(maskGenerationArray[currSubstack], newX, newY, directories, imageNameRaw);

				//Save our maxima images
				saveMaximaImages(directories, imageNameRaw, maskGenerationArray[currSubstack]);
				
				//Close everything
				Housekeeping();

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






							//Set the values in our cell position marking table according to the 
							//image we've just processed, set processed to 1, save the table, and 
							//lastly save a .txt file which we use to check quickly whether we've
							//processed this image as opening the table to read values for each
							//image takes ages
							File.saveString(stringToSave, directories[1]+imageNames[3]+"/Cell Coordinate Masks/"+stringToSave+".txt");
							procForTable[i0] = 1;
						}
			
						Housekeeping();
	
					}
						
					//Set the values in our cell position marking table according to the 
					//image we've just processed, set processed to 1, save the table, and 
					//lastly save a .txt file which we use to check quickly whether we've
					//processed this image as opening the table to read values for each
					//image takes ages
					selectWindow("Cell Position Marking");
					Table.setColumn("Substack", subName);
					Table.setColumn("Processed", procForTable);
					Table.save(directories[1] + imageNames[3] + "/Cell Coordinate Masks/Cell Position Marking.csv");
					currName = Table.title;
					Table.reset(currName);
	
				}
			}
		}
		Housekeeping();

		toConcat = newArray(1);
		finalImagestoUseArray = newArray(1);
		count = 0;
		for(row = 0; row < images.length; row++) {
			
			//If we kept the image (and have analysed it)
			if(kept[row] == 1) {
		
				//We need to make 3 chunks of images to analyse - so we loop 3 times
				//Create a substack of 10um deep using our dividingArraySlices array 
				//(i.e. 21-30um, 51-60um, and 81-90um)
				checkIt = false;
				for(i0=0; i0<noStacksRaw[row]; i0++) {
			
					imgName="Substack ("+maskGenerationArray[i0]+")"; 
					stringToSave = "Substack ("+maskGenerationArray[i0]+") positions marked"; 

					//Check if we've already generated cell locations for this substack
					//for this image
					if(File.exists(directories[1] + images[row] + "/Cell Coordinate Masks/"+stringToSave+".txt")==1) {
						checkIt = true;
						i0 = 1e99;
					}
				}
			
				//If we haven't calculated the threshold for this image, add it to our finalImagestoUseArray
				if(checkIt== true) {
				
					//If we're not on the first image, we concatenate our finalImagesToUseArray with our toConcat array
					if(count!=0) {
						finalImagestoUseArray = Array.concat(finalImagestoUseArray, toConcat);
					}

					//If the image contains " .tif" in the name we set finalImagestoUseArray[count] to the image name without it,
					//else we just set it to that name
					finalImagestoUseArray[count] = images[row];
					
					//Increase our count by one
					count++;
				}
			}
		}

		if(finalImagestoUseArray[0] != 0) {
			//Once we've automatically generated cell masks for all images, we then loop through
			//all the images again
			for (i=0; i<finalImagestoUseArray.length; i++) {
				
				//Work out the animal and timepoint labels for the current image based on 
				//its name
				imageNames = newArray(4);
				forUse = finalImagestoUseArray[i] + ".tif";
				getAnimalTimepointInfo(imageNames, forUse);
				
				print("Checking ", imageNames[3]);
				
				//Get the list of the files in our cell coordinates subfolder
				coordinateFiles = getFileList(directories[1] + imageNames[3] + "/Cell Coordinates/");
		
				//If we have at least a file there (we've generated some coordinates)
				if(coordinateFiles.length!=0) {
			
			
					//If we have a cell position marking.csv window open already, just reset it instead of closing
					if(isOpen("Cell Position Marking.csv")==true){
						selectWindow("Cell Position Marking.csv");
						Table.reset("Cell Position Marking.csv");
					}
					
					//Open our cell position marking csv file
					Table.open(directories[1] + imageNames[3] + "/Cell Coordinate Masks/Cell Position Marking.csv");
					
					//Get out the QC column from the cell position marking table and calculate its mean
					selectWindow("Cell Position Marking.csv");
					QCArray = Table.getColumn("QC");
		
					//Get out the QC values for the substacks that we actually have coordinate files for
					QCArray = Array.slice(QCArray, 0, coordinateFiles.length);
					Array.getStatistics(QCArray, QCMin, QCMax, QCMean, QCSD);
					
					//If the mean isn't 1 (i.e. not all substacks for this image have had their masks quality controlled
					//since once they're QC'd we set the QC value to 1, therefore when they're all done the QC value mean
					//should =1) then we proceed
					if(QCMean!=1) {
		
						//Rename our window to without the .csv
						selectWindow("Cell Position Marking.csv");
						Table.rename("Cell Position Marking.csv", "Cell Position Marking");
			
						//Loop through the substacks we have coordinates for
						for(i0=0; i0<coordinateFiles.length; i0++) {
					
							//Get the QC value of the current substack, and set the variables badReg and badDetection to 0
							//(These variables set whether the image either didn't register properly or if the automatic
							//mask detection was no good)
							currentQC = QCArray[i0];
							badReg = 0;
							badDetection = 0;
			
							//If the current substack hasn't been quality controleld
							if(currentQC==0) {
								
								//Create a variable to store the name of the current substack
								imgName="Substack ("+maskGenerationArray[i0]+")"; 
								print(directories[1]+imageNames[3]+"/Cell Coordinate Masks/CP mask for Substack ("+maskGenerationArray[i0]+").tif");
				
					
								//Open its cell placement masks image and the image that has the automated CPs
								open(directories[1]+imageNames[3]+"/Cell Coordinate Masks/CP mask for Substack ("+maskGenerationArray[i0]+").tif");
								if(is("Inverting LUT")==true) {
									run("Invert LUT");
								}
								
								selectWindow("CP mask for Substack (" + maskGenerationArray[i0]+").tif");
								rename("MAX");
	
								print(directories[1]+imageNames[3]+"/Cell Coordinates/CP coordinates for Substack ("+maskGenerationArray[i0]+").csv");
								print(File.exists(directories[1]+imageNames[3]+"/Cell Coordinates/CP coordinates for Substack ("+maskGenerationArray[i0]+").csv"));
	
								Table.open(directories[1]+imageNames[3]+"/Cell Coordinates/CP coordinates for Substack ("+maskGenerationArray[i0]+").csv");
								selectWindow("CP coordinates for Substack ("+maskGenerationArray[i0]+").csv");
								xPoints = Table.getColumn("X");
								yPoints = Table.getColumn("Y");
	
								selectWindow("MAX");
								makeSelection("point", xPoints, yPoints);
								setBatchMode("Exit and Display");
		
								//If there are cell ROIs generated
								if(selectionType() != -1) {
									roiManager("add");
									selectWindow("MAX");
									roiManager("select", 0);
								
									//Ask the user whether these automated masks were generated well or not
									goodCPs = userApproval("Check that the automated CP selection has worked", "CP Checking", "Automated CPs Acceptable?");
		
								} else {
									goodCPs = false;
								}
													
								//If they're poor
								if (goodCPs == false) {
					
					
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
		
									//Convert the boolean user choices to integers
									badReg = 0;
									if(badRegRaw == true) {
										badReg = 1;
									}
									badDetection = 0;
									if(badDetectionRaw == true) {
										badDetection = 1;
									}
									
								//If the CP generation was good
								} else {
									
									//Set the tool to multipoint and ask the user to click on any cells the
									//automatic placement generation missed
									setTool("multipoint");
									selectWindow("MAX");
									roiManager("Show All");
									waitForUser("Click on cells that were missed by automatic detection, if any");
									
									//If the user clicked on additional cells
									if(selectionType()!=-1) {
										
										//Add the cell locations to the roiManager and measure them to get their X,Y coords
										//in the results window
										roiManager("add");
										run("Set Measurements...", "centroid redirect=None decimal=0");
										run("Clear Results");
										roiManager("Select", 1);
										roiManager("Measure");
										
										setBatchMode(true);
										
										//Get the X,Y coords from the results window
										selectWindow("Results");
										X = Table.getColumn("X");
										Y = Table.getColumn("Y");
				
										//Concatenate the two - the original X and Y coords and the ones we've added
										newX = Array.concat(xPoints, X);
										newY = Array.concat(yPoints, Y);
		
										//Then set the concatenated arrays as the X and Y results in the results table before
										//saving it over the CP coordinates file
										Table.setColumn("X", newX);
										Table.setColumn("Y", newY);
										Table.update;
										saveAs("Results", directories[1]+imageNames[3]+"/Cell Coordinates/CP coordinates for " + imgName + ".csv");
										selectWindow("CP coordinates for Substack ("+maskGenerationArray[i0]+").csv");
										run("Close");
									}
								
								}
				
								//If the image had bad detection but otherwise the registration was fine
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