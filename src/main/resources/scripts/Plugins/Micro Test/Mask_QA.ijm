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

			if(tcsMasksGenerated[TCSLoops] == 1 && tcsQCChecked[TCSLoops] == -1) {

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

				//We now loop through all the cells for this given input image
				for(currCell=0; currCell<maskName.length; currCell++) {

                    if(maskSuccess[currCell] == 1 && maskQA[currCell] == -1) {
			
                        print("QC for: ", maskName[currCell]);
                        print("Cell no.: ", currCell+1, " / ", maskName.length);

						//Open this TCS's version of the mask
                        cellMaskLoc = TCSDir + "Cell Masks/" + maskName[currCell];
                        open(cellMaskLoc);
						selectWindow(File.getName(cellMaskLoc));
						
						//Create a selection from the mask
                        run("Create Selection");
                        getSelectionCoordinates(xpoints, ypoints);

                        substackCoordName = substring(maskName[currCell], indexOf(maskName[currCell], 'for'));

						//Open the LR associated with this mask and apply the selection
                        cellLRLoc = directories[1]+imageNameRaw+"/Local Regions/" + "Local region " + substackCoordName;
                        open(cellLRLoc);
                        selectWindow(File.getName(cellLRLoc));
						makeSelection('freehand', xpoints, ypoints);
						
						setBatchMode("Show");
						approved = userApproval("Check image for issues", "Mask check", "Keep the image?");

						if(approved == true) {
							maskQA[currCell] = 1;
						} else {
							maskQA[currCell] = 0;
						}

						somaName = directories[1]+imageNameRaw+"/Somas/Soma mask " + substackCoordName;

						if(approved == true && File.exists(somaName) != 1) {

						}
				
									selectWindow(currentMask);
									run("Create Selection");
									Roi.setStrokeColor("red");
									roiManager("Add");
				
									//Soma mask generation is done below - auto thresholding, and clearing outside the cell mask etc. etc.
									selectWindow(LRImage);
									run("Select None");
									run("Duplicate...", " ");
									selectWindow(LRTifLess+"-1.tif");
									roiManager("Select", 0);
									run("Clear Outside");
									run("Select None");
									selectWindow(LRTifLess+"-1.tif");
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
									
									run("Invert");
									run("Open");
									run("Watershed");
			
									for(i1=0; i1<2; i1++) {
										run("Erode");
									}
			
									for(i1=0; i1<3; i1++) {
										run("Dilate");
									}
			
									//Here we check how many particles have been left after this process
									run("Auto Threshold", "method=Default");
									run("Analyze Particles...", "size=20-Infinity circularity=0.60-1.00 show=Masks display clear");
									run("Clear Results");
									run("Set Measurements...", "area mean redirect=None decimal=2");
									selectWindow("Mask of " + LRTifLess + "-1.tif");
									run("Measure");
									
									getStatistics(imageArea);
		
									if(getResult("Mean")==0 || getResult("Mean")==255) {
										keep = false;
										somaArea = imageArea;
									} else {
										run("Create Selection");
										run("Clear Results");
										run("Measure");
										somaArea = getResult("Area");
										run("Select None");
									}
				
									//If only one particle is present
									if(somaArea!= imageArea && nResults==1) {
									
										selectWindow("Mask of " + LRTifLess + "-1.tif");
										rename(imageNamesArray[1]);
										run("Create Selection");
										roiManager("Add");
										selectWindow(LRImage);
										roiManager("select", 1);
										roiManager("Show All");
										keep = userApproval("Check image soma mask", "Soma check", "Keep the soma mask?");
			
										if(keep == true) {
											selectWindow(imageNamesArray[1]);
											saveAs("tiff", somaName);
											run("Close");
										}
			
										roiManager("select", 1);
										roiManager("delete");
				
									} 

									//If we have more or less than 1 particle, we have to draw our own soma mask and we do that
									//Could incorporate this with the code above as it does very similar things?
									if (keep==false || somaArea == imageArea) {
				
										waitForUser("Need to draw manual soma mask");
										selectWindow(LRImage);
										roiManager("Show All");
			
										for(i1=0; i1<3; i1++) {
											run("In [+]");
										}
			
										run("Scale to Fit");
										setTool("polygon");
										setBatchMode("Exit and Display");
										waitForUser("Draw appropriate soma mask");
										roiManager("add");
										roiManager("select", 1);
										run("Create Mask");
										selectWindow("Mask");
										saveAs("tiff", somaName);
										run("Close");
										
									}
			
									selectWindow(LRTifLess+"-1.tif");
									run("Close");
									roiManager("deselect");
									roiManager("delete");
								}
				
								//Here if we want to trace cells, and haven't traced the cell in questions and we've deicded to keep it, then we do just that
								if(selection[4]==1 && currentMaskValues[3]==0 && currentMaskValues[2]==1) {
				
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
		}
	}
}