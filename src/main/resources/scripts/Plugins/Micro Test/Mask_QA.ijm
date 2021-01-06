//////////////////////////Quality Control//////////////////////////////////////
//If the user wants to perform quality control on the cells
if(analysisSelections[4] == true) {

	//Set the background color to black otherwise this messes with the clear outside command
	setBackgroundColor(0,0,0);

	//Loop through our output images
	loopThrough = getFileList(directories[1]);

	for(i=0; i<loopThrough.length; i++) {

		//Make sure we're not working with non-image folders
		proceed = false;
		if(loopThrough[i] != "Images To Use.csv" && loopThrough[i] != "fracLac/") {
			proceed = true;	
			imageNames = newArray(4);
			forUse = File.getName(loopThrough[i]) + ".tif";
			getAnimalTimepointInfo(imageNames, forUse);	
		}

		//If a TCS status file exists already
		if(proceed== true && File.exists(directories[1] + imageNames[3] + "/TCS Status.csv")==1) {
			
			//Read it in and get whether we've QC'd all TCS vals
			open(directories[1] + imageNames[3]+"/TCS Status.csv");
			selectWindow("TCS Status.csv");
			numberOfLoops = Table.size;

			print(imageNames[3]);
			qcCol = Table.getColumn("QC Checked");
			Array.getStatistics(qcCol, qcMin, qcMax, qcMean, qcSD);
			selectWindow("TCS Status.csv");
			Table.reset("TCS Status.csv");
			
			//If we haven't QC'd all the TCS levels for this datapoint (if we had, qcMean would be 1) then proceed
			if(qcMean!=1) {

				print("Need to QC");
				//Fill the TCS Status table with current TCS status values if they already exist
			
				TCSColumns = newArray("TCS", "Masks Generated", "QC Checked", "Analysed");
				TCSValues = newArray(numberOfLoops*TCSColumns.length);
				
				//First numberOfLoops indices are TCS, then Masks Generated etc.
				TCSResultsRefs = newArray(directories[1]+imageNames[3]+"/TCS Status.csv", 
					directories[1]+imageNames[3]+"/TCS Status.csv", 
					directories[1]+imageNames[3]+"/TCS Status.csv", 
					directories[1]+imageNames[3]+"/TCS Status.csv");
				TCSResultsAreStrings = newArray(false, false, false, false);
			
				fillArray(TCSValues, TCSResultsRefs, TCSColumns, TCSResultsAreStrings, true); 
			
				Table.create("TCS Status");
				selectWindow("TCS Status");
				for(i0=0; i0<numberOfLoops; i0++) {
					for(i1=0; i1<TCSColumns.length; i1++) {
						Table.set(TCSColumns[i1], i0, TCSValues[(numberOfLoops*i1)+i0]);
					}
				}
				Table.update;
		
				//We QC all masks for all TCSs
				for(TCSLoops=numberOfLoops-1; TCSLoops>=0; TCSLoops--) {
					print("TCS " + TCSLoops);
					
					selectWindow("TCS Status");
					currentLoopValues = newArray(TCSColumns.length);
					//[0] is TCS, [1] is masks generated, [2] is QC checked, [3] is analysed

					currentLoopValues[0] = Table.get("TCS", TCSLoops);

					//Booleans for whether we have TCS values preceding or following this one
					prevExists = false;
					nextExists = false;

					selectWindow("TCS Status");
					for(i0 = 0; i0<Table.size; i0++) {
						if(currentLoopValues[0] == Table.get("TCS", i0)) {
							
							selectWindow("TCS Status");
							//Here we fill our currentLoopValues table with the TCSValues data that corresponds to the TCS value
							//we're current processing - this will be a bunch of zeros if we haven't processed anything before
							for(i1=0; i1<TCSColumns.length; i1++) {
								currentLoopValues[i1] = Table.get(TCSColumns[i1], i0);
							}

							//If we're not on the first one, if we have a directory for the previous TCS get out the kept 
							//and names columns from it
							if(i0 > 0) {
								previousTCSDir=directories[1]+imageNames[3]+"/TCS"+Table.get("TCS", (i0-1))+"/QC Checked.csv";
								selectWindow("TCS Status");
								if(File.exists(previousTCSDir) && Table.get("QC Checked", (i0-1)) == 1) {
									prevExists = true;
									open(previousTCSDir);
									selectWindow("QC Checked.csv");
									keptPrevTCS=Table.getColumn("Keep");
									namesPrevTCS=Table.getColumn("Mask Name");
									Table.reset("QC Checked.csv");
								}
							}

							//If we're not on the last one get out which masks we we kept from the next TCS
							if(i0 < Table.size-1) {
								nextTCSDir=directories[1]+imageNames[3]+"/TCS"+Table.get("TCS", (i0+1))+"/QC Checked.csv";
								selectWindow("TCS Status");
								if(File.exists(nextTCSDir) && Table.get("QC Checked", (i0+1)) == 1) {
									nextExists = true;
									open(nextTCSDir);
									selectWindow("QC Checked.csv");
									keptNextTCS=Table.getColumn("Keep");
									namesNextTCS=Table.getColumn("Mask Name");
									Table.reset("QC Checked.csv");
								}
							}
							i0 = Table.size;
						}
					}
			
					//If the QC for this TCS hasn't been done in its entirety..
					if(currentLoopValues[2]==0) {

						//Get the paths for our storage folders
						TCSDir=directories[1]+imageNames[3]+"/"+"TCS"+currentLoopValues[0]+"/";
						storageFoldersArray=newArray(storageFolders.length);
						//[2] is somas, [3] is maskDir, [4] is localregion
						
						for(i0=0; i0<storageFolders.length; i0++) {
							if(i0<3) {
								parentDir=directories[1]+imageNames[3]+"/";	
							} else {
								parentDir=TCSDir;	
							}
							storageFoldersArray[i0]=parentDir+storageFolders[i0];
						}
		
						//Our maskName array is just a list of the files in our maskDirFiles folder
						//Fill QC checked with preivous results if they exist
						maskDirFiles = getFileList(storageFoldersArray[3]);

						//Get out our cell check, keep, and traced values for each cell
						valuesToRecord = newArray("Single Cell Check", "Keep", "Traced"); 
						analysisRecordInput = newArray(maskDirFiles.length*valuesToRecord.length);
						resultsTableRefs = newArray(TCSDir+"QC Checked.csv", TCSDir+"QC Checked.csv", TCSDir+"QC Checked.csv");
						resultsAreStrings = newArray(false, false, false);
						fillArray(analysisRecordInput, resultsTableRefs, valuesToRecord, resultsAreStrings, true);

						//Add on our mask names to this fetched array
						maskName=Array.copy(maskDirFiles);
						analysisRecordInput = Array.concat(maskName, analysisRecordInput);
						toAdd = newArray("Mask Name");
						tableLabels = Array.concat(toAdd, valuesToRecord);

						//Repopulate the table if it hasn't already been done
						Table.create("QC Checked");
						selectWindow("QC Checked");

						for(i0=0; i0<maskDirFiles.length; i0++) {
			
							currentMaskValues = newArray(4);
							//[0] is mask name, [1] is single cell check, [2] is keep, [3] is trace
					
							for(i1=0; i1<currentMaskValues.length; i1++) {
								currentMaskValues[i1] = analysisRecordInput[(maskDirFiles.length*i1)+i0];
							}
							
							//Here we get out the values for whether the images have been checked for overall issues (singleChecked),
							//Whether we decided to keep the image (keepImage), and whether (if the user wants to trace the cells), the cells
							//have been traced
			
							cutName = substring(maskDirFiles[i0], indexOf(maskDirFiles[i0], "Substack"));
							imageNamesArray = newArray("Local region for " +cutName, "Candidate Soma Mask for " + cutName);

							//Get the x, y, and substack location of the current cell
							print(maskName[i0]);
							xCoord = parseInt(substring(maskName[i0], indexOf(maskName[i0], "x ")+2, indexOf(maskName[i0], "y")-1));
							yCoord = parseInt(substring(maskName[i0], indexOf(maskName[i0], "y ")+2, indexOf(maskName[i0], ".tif")-1));
							substackLoc = substring(maskName[i0], 0, indexOf(maskName[i0], "x"));
							print(xCoord);
							print(yCoord);
			
							//Here, we look for the kept value of the current coordinates in the previous TCS directory
							//if it was kept previously, set keptPrevTCS to 1, otherwise to 0
							currentKeptPrev = 0;
							currentCheckPrev = 0;
							currentKeptNext = 0;
							currentCheckNext = 0;
							somaName = storageFoldersArray[2]+imageNamesArray[1];
							otherSomaName = storageFoldersArray[2]+imageNamesArray[1];

							//If we have a previous TCS
							if(prevExists == true) {
								returnArray = newArray(3);
								outputArray = checkForSameCell(namesPrevTCS, maskName[i0], keptPrevTCS, currentKeptPrev, currentCheckPrev, xCoord, yCoord, substackLoc, storageFoldersArray[2], returnArray);
								currentKeptPrev = outputArray[0];
								currentCheckPrev = outputArray[1];
								otherSomaName = outputArray[2];
							}

							//Same deal for if we have a subsequent TCS
							if(nextExists == true) {
								returnArray = newArray(3);
								outputArray = checkForSameCell(namesNextTCS, maskName[i0], keptNextTCS, currentKeptNext, currentCheckNext, xCoord, yCoord, substackLoc, storageFoldersArray[2], returnArray);
								currentKeptNext = outputArray[0];
								currentCheckNext = outputArray[1];
								otherSomaName = outputArray[2];
							}
							
							checkMask = false;
							pass = false;
							fail = false;

							if(currentMaskValues[1] == 0 && currentCheckNext == 1 && currentKeptNext == 1) {
								checkMask = false;
								print("Checked and passed higher TCS value, no need to check lower");
								pass = true;
							} else if (currentMaskValues[1] == 0 && currentCheckNext == 1 && currentKeptNext == 0) {
								checkMask = true;
								print("Checked and failed higher TCS value, need to check lower");
							} else if(currentMaskValues[1] == 0 && currentCheckNext == 0) {
								checkMask = true;
								print("Haven't checked at a higher TCS, need to check at this level");
							} 
							
							if (currentMaskValues[1] == 0 && currentCheckPrev == 1 && currentKeptPrev == 0) {
								checkMask = false;
								print("Checked and failed at a lower TCS value, no need to check higher");
								fail = true;
							}

							//If we're tracing processes and we haven't traced the mask and it wasn't disregarded before
							if(selection[4] == 1 && currentMaskValues[3] == 0 && fail!= true) {
								checkMask = true;
								print("Need to trace");
							}

							//If we're not checking because we don't need to because it'll pass, set kept to 1
							if(pass == true) {
								currentMaskValues[2]=1;
							}
							//If we're not checking because it will fail, set kept to 0
							if(fail == true) {
								currentMaskValues[2]=0;
							}

							//If we need to QC our mask
							if(checkMask == true) {
			
								print("QC for: ", maskDirFiles[i0]);
								print("Cell no.: ", i0, " / ", maskDirFiles.length);
			
								open(storageFoldersArray[3]+maskDirFiles[i0]);
								currentMask = getTitle();
								tifLess = substring(currentMask, 0, indexOf(currentMask, ".tif"));
								run("Select None");
								run("Auto Threshold", "method=Default");
								
								open(storageFoldersArray[4]+imageNamesArray[0]);
								LRImage = getTitle();
								LRTifLess = substring(LRImage, 0, indexOf(LRImage, ".tif"));
				
								//Here we open the local regions, outline the mask, and ask the user whether to keep the image or not
								if(currentMaskValues[1]==0) {
				
									setBatchMode("Exit and Display");
									selectWindow(currentMask);
									run("Create Selection");
									roiManager("Add");
									
									selectWindow(LRImage);
									roiManager("show all");
									approved = userApproval("Check image for issues", "Soma check", "Keep the image?");
			
									if(approved == true) {
										currentMaskValues[2] = 1;
									} else {
										currentMaskValues[2] = 0;
									}
				
									//The variable indicates we've checked the mask
									currentMaskValues[1]=1; 
			
									roiManager("deselect");
									roiManager("delete");
										
								}
				
								//Here if we decided to keep the mask and we haven't generated a soma mask for it yet, we do that
								//The soma masks we generate aren't TCS specific so we save them in the overall output folder and check for all TCS's whether 
								//we have a soma mask for the coordinates
								//We check whether our soma mask has been created by looking in the directory where we would have saved it
								if(currentMaskValues[2]==1 && File.exists(somaName)==0) {
				
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