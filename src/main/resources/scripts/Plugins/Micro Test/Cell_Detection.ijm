
//These folder names are where we store various outputs from the processing 
//(that we don't need for preprocessing)
storageFolders=newArray("Cell Coordinates/", "Cell Coordinate Masks/",
    "Somas/", "Candidate Cell Masks/", "Local Regions/", "Results/");

//Set the size of the square to be drawn around each cell in um
LRSize = 120;


////////////////////////////////////////////////////////////////////////////////	
//////////////////////////////Cell Position Marking/////////////////////////////
////////////////////////////////////////////////////////////////////////////////


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
autoProcessed = getTableColumn(imagesToUseFile, "Auto Processing");
autoPassedQA = getTableColumn(imagesToUseFile, "Auto QA Passed");
manualProcessed = getTableColumn(imagesToUseFile, "Manual Processing");
manualPassedQA = getTableColumn(imagesToUseFile, "Manual QA Passed");

for(currImage = 0; currImage < imageName.length; currImage++) {
    if(autoPassedQA[currImage] == 1 || manualPassedQA[currImage] == 1) {

        //If the image was kept, count how many 10um thick substacks we can make with at least
        //10um spacing between them, and 10um from the bottom and top of the stack
        run("TIFF Virtual Stack...", "open=["+directories[1]+File.getNameWithoutExtension(imageName[currImage])+"/"+File.getNameWithoutExtension(imageName[currImage])+" processed.tif]");
        getVoxelSize(vWidth, vHeight, vDepth, vUnit);
        
        //Calculate how much Z depth there is in the stack
        zSize = nSlices*vDepth;

        //Calculate how many 10um thick substacks we can make from this stack, including a user defined buffer size
        //between substacks
        noSubstacks = floor(zSize / (zBuffer+10));

        //Fill maskGenerationArray with a string of the range of z planes to include in each substack
        maskGenerationArray = newArray(noSubstacks);
        for(currSubstack = 0; currSubstack < noSubstacks; currSubstack++){
            //Calculate what 
            startZ = (zBuffer * (currSubstack+1)) + (currSubstack * 10);
            maskGenerationArray[currSubstack] = toString(startZ) + '-' + toString(startZ + 10);
        }

    }
}


		//Here we loop through all the images in the images to use table
		//No counts stores how many substacks we can make from our image
		toConcat = newArray(1);
		finalImagestoUseArray = newArray(1);
		noStacks = newArray(1);
		noStacksRaw = newArray(images.length);
		count = 0;
		for(row = 0; row < images.length; row++) {
			
			//If we kept the image (and have analysed it)
			if(kept[row] == 1) {

				//If the image was kept, count how many 10um thick substacks we can make with at least
				//10um spacing between them, and 10um from the bottom and top of the stack
				run("TIFF Virtual Stack...", "open=["+directories[1]+images[row]+"/"+images[row]+" processed.tif]");
				getVoxelSize(vWidth, vHeight, vDepth, vUnit);
				zSize = nSlices*vDepth;
				counting = 0;
				for(currZ = 10; currZ < zSize; currZ++) {
					if(currZ%20 == 0 && currZ <= (zSize-30)) {
						counting = counting+1;
					}
				}

				//Fill maskGenerationArray with a string of the range of z planes to include in each substack
				countingTwo = 0;
				maskGenerationArray = newArray(counting);
				for(currZ = 10; currZ < zSize; currZ++) {
					if(currZ%20 == 0 && currZ <= (zSize-30)) {
						maskGenerationArray[countingTwo] = toString(currZ)+"-"+toString((currZ+10));
						countingTwo = countingTwo + 1;
					}
				}

				noStacksRaw[row] = maskGenerationArray.length;

				//For each substack, check if we've made cell locations
				checkIt = false;
				for(i0 = 0; i0<maskGenerationArray.length; i0++) {
			
					stringToSave = "Substack ("+maskGenerationArray[i0]+") positions marked"; 

					//Check if we've already generated cell locations for this substack
					//for this image
					if(File.exists(directories[1]+images[row]+"/Cell Coordinate Masks/"+stringToSave+".txt")==0) {
						checkIt = true;
						i0 = 1e99;
					}
				}

				//If we haven't got all the coordinates for every substack for this image
				if(checkIt== true) {
				
					//If we're not on the first image, we concatenate our finalImagesToUseArray with our toConcat array
					if(count!=0) {
						finalImagestoUseArray = Array.concat(finalImagestoUseArray, toConcat);
						noStacks = Array.concat(noStacks, toConcat);
					}

					finalImagestoUseArray[count] = directories[1]+images[row]+"/"+images[row]+" processed";

					//Add how many substacks we can make for this image
					noStacks[count] = maskGenerationArray.length;
					
					//Increase our count by one
					count++;
				}
			} else {
				noStacksRaw[row] = 0;
			}
		}

		if(finalImagestoUseArray[0] != 0) {
			//Loop through the images that we want to calculate our motility indices for
			for(i=0; i<finalImagestoUseArray.length; i++) {
	
				Housekeeping();
			
				//Work out the animal and timepoint labels for the current image based on its name
				imageNames = newArray(4);
				print(finalImagestoUseArray[i]);
				procLoc = indexOf(finalImagestoUseArray[i], " processed");
				forUse = substring(finalImagestoUseArray[i], 0, procLoc) + ".tif";
			  	getAnimalTimepointInfo(imageNames, forUse);
				
				//Look for the files in the cell coordinates masks folder for that image
				maskFolderFiles = getFileList(directories[1] + imageNames[3] + "/Cell Coordinate Masks/");
		
		      	//Set found to 0
				found = 0;
		      
		     	//Loop through the files and if we find a .txt file (an indicator that 
		      	//we've previuosly marked coordinates for this image) then we add 1 to 
		      	//found
				for(i0 = 0; i0<maskFolderFiles.length; i0++) {
					if(indexOf(maskFolderFiles[i0], ".txt")>0) {
						found++;
					}
				}
				
				//If found doesn't equal the number of stacks we can make for this image (i.e. we haven't marked coordinates for all
				//substacks of out input image, even if we have for some) then we continue
				if(found!=noStacks[i]) {		
					
					//Here we make any storage folders that aren't related to TCS and 
					//haven't already been made
					for(i0=0; i0<storageFolders.length; i0++) {
						dirToMake=directories[1]+imageNames[3]+"/"+storageFolders[i0];
						if(File.exists(dirToMake)==0) {
							File.makeDirectory(dirToMake);
						}
					}	
				
					//If the cell position marking table isn't open, we create it
					if(isOpen("Cell Position Marking")==0) {
						Table.create("Cell Position Marking");
					} else {
						Table.reset("Cell Position Marking");
					}
						
					//Create an array here of the columns that will be / are in the cell position marking table
					TableColumns = newArray("Substack", "Bad Registration", "Bad Detection", "Processed", "QC");
						                        
					//TableValues is an array we'll fill with the values from any existing cell position marking table for this image
					TableValues = newArray(noStacks[i]*TableColumns.length);
						
					//TableResultsRefs is an array of the location where we would find any
					//previuosly existing table, repeated for each column
					TableResultsRefs = newArray(directories[1] + imageNames[3] + "/Cell Coordinate Masks/Cell Position Marking.csv", 
						directories[1] + imageNames[3] + "/Cell Coordinate Masks/Cell Position Marking.csv", 
						directories[1] + imageNames[3] +  "/Cell Coordinate Masks/Cell Position Marking.csv", 
						directories[1] + imageNames[3] + "/Cell Coordinate Masks/Cell Position Marking.csv", 
						directories[1] + imageNames[3] + "/Cell Coordinate Masks/Cell Position Marking.csv");
							
					//This tells the function whether the results we're getting are strings
					TableResultsAreStrings = newArray(true, false, false, false, false);
						
					//Run the fillArray function to fill TableValues
					fillArray(TableValues, TableResultsRefs, TableColumns, TableResultsAreStrings, true);
				
					//Here we fill our current or new cell position marking table with data 
					//from our TCSValues array
					selectWindow("Cell Position Marking");
					for(i0=0; i0<noStacks[i]; i0++) {
						for(i1=0; i1<TableColumns.length; i1++) {
							Table.set(TableColumns[i1], i0, TableValues[(noStacks[i]*i1)+i0]);
						}
					}
	
					subName = newArray(noStacks[i]);
					procForTable = newArray(noStacks[i]);
				
					//We loop through each substack now
					for(i0=0; i0<noStacks[i]; i0++) {
				
						imgName="Substack ("+maskGenerationArray[i0]+")"; 
						stringToSave = "Substack ("+maskGenerationArray[i0]+") positions marked"; 
						subName[i0] = "Substack (" +maskGenerationArray[i0]+ ")";
	
						if(File.exists(directories[1] + imageNames[3] + "/Cell Coordinate Masks/"+stringToSave+".txt")==1) {
							procForTable[i0] = 1;
						//Check if we've already generated cell locations for this substack for this image
						} else {
							print("Marking ", imageNames[3], " at ", imgName);
								
							//Open the processed image, make a substack, max project it
							open(directories[1] + imageNames[3] + "/" + imageNames[3] +" processed.tif");
							if(is("Inverting LUT")==true) {
								run("Invert LUT");
							}
	
							rename(imageNames[3]);
							run("Make Substack...", " slices="+maskGenerationArray[i0]+"");
							selectWindow(imgName);
							run("Z Project...", "projection=[Average Intensity]");
							selectWindow("AVG_"+imgName);
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
							selectWindow("Results");
							newX = Table.getColumn("X");
							newY = Table.getColumn("Y");
	
							//If for this image we already have somas generated then get the corodinates of the somas for this substack and add these
							//to the maxima locations, removing any soma locations that are already represented in the maxima locations
							if(File.exists(directories[1]+imageNames[3]+"/Somas/")==1) {
								somaFiles = getFileList(directories[1]+imageNames[3]+"/Somas/");
								allX = newArray(somaFiles.length);
								allY = newArray(somaFiles.length);
								count = 0;
								for(currSoma = 0; currSoma < somaFiles.length; currSoma++) {
									if(indexOf(somaFiles[currSoma], imgName)>-1){
										allX[count] = parseFloat(substring(somaFiles[currSoma], indexOf(somaFiles[currSoma], "x ") +1, indexOf(somaFiles[currSoma], " y")));
										allY[count] = parseFloat(substring(somaFiles[currSoma], indexOf(somaFiles[currSoma], "y ") +1));
										for(currNew = 0; currNew < numbResults; currNew++) {
											if(newX[currNew] == allX[count] && newY[currNew] == allY[count]) {
												allX[count] = 0;
												allY[count] = 0;
											}
										}
										count++;
									}
								}
	
								//Remove zeros from our new coordinates
								cleanX = newArray(1);
								cleanX = removeZeros(allX, cleanX);		
								cleanY = newArray(1);
								cleanY = removeZeros(allY, cleanY);
	
								//Concatenate our new points (if any don't match) to our old points
								newX = Array.concat(newX, cleanX);
								newY = Array.concat(newY, cleanY);
							}
	
							//Here we load in the coordinates file if it already exists and remove any of these additional points if they are already
							//represented, then concatenate them
							if(File.exists(directories[1]+imageNames[3]+"/Cell Coordinates/CP coordinates for " + imgName + ".csv")==1) {
								Table.open(directories[1]+imageNames[3]+"/Cell Coordinates/CP coordinates for " + imgName + ".csv");
								selectWindow("CP coordinates for " + imgName + ".csv");
								oldX = Table.getColumn("X");
								oldY = Table.getColumn("Y");
	
								//Looping through our new points and comparing them to our existing points, if they're the same, set their values to 0
								for(currRow = 0; currRow < oldX.length; currRow++) {
									rX = oldX[currRow];
									rY = oldY[currRow];
									for(currResult = 0; currResult < newX.length; currResult++) {
										if(newX[currResult] == rX && newY[currResult] == rY) {
											oldX[currRow] = 0;
											oldY[currRow] = 0;
										}
									}
								}
	
								//Remove zeros from our new coordinates
								cleanX = newArray(1);
								cleanX = removeZeros(oldX, cleanX);		
	
								cleanY = newArray(1);
								cleanY = removeZeros(oldY, cleanY);
	
								//Concatenate our new points (if any don't match) to our old points
								newX = Array.concat(newX, cleanX);
								newY = Array.concat(newY, cleanY);
	
							}
	
							//Create / reset a table to store our coordinates, set the X and Y columns appropriately, save
							if(isOpen("CP coordinates for " + imgName + ".csv")==1) {
								selectWindow("CP coordinates for " + imgName + ".csv");
								Table.reset("CP coordinates for " + imgName + ".csv");
							} else {
								Table.create("CP coordinates for " + imgName + ".csv");
							}
	
							selectWindow("CP coordinates for " + imgName + ".csv");
							if(newX.length == 0) {
								Table.setColumn("X", 1);
								Table.setColumn("Y", 1);
							} else {
								Table.setColumn("X", newX);
								Table.setColumn("Y", newY);
							}
								
							saveAs("Results", directories[1]+imageNames[3]+"/Cell Coordinates/CP coordinates for " + imgName + ".csv");
	
							selectWindow("CP coordinates for " + imgName + ".csv");
							Table.reset("CP coordinates for " + imgName + ".csv");
								
							selectWindow("AVG Maxima");
							run("Select None");
	
							//Save the selections around the maxima and the image itself
							saveAs("tiff", directories[1] + imageNames[3] + "/Cell Coordinate Masks/Automated CPs for Substack (" + maskGenerationArray[i0] + ").tif");
							selectWindow("AVG");
							run("Select None");
							saveAs("tiff", directories[1] + imageNames[3] + "/Cell Coordinate Masks/CP mask for Substack (" + maskGenerationArray[i0] + ").tif");
	
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