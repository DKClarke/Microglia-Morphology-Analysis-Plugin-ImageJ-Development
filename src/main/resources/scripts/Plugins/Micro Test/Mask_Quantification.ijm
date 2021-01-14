
if(analysisSelections[2] == true || analysisSelections[3] == true || analysisSelections[4] == true || analysisSelections[5] == true) {
	//These folder names are where we store various outputs from the processing 
	//(that we don't need for preprocessing)
	storageFolders=newArray("Cell Coordinates/", "Cell Coordinate Masks/",
		"Somas/", "Candidate Cell Masks/", "Local Regions/", "Results/");

	//Set the size of the square to be drawn around each cell in um
	LRSize = 120;
}

if(analysisSelections[5] == true) {
	/////////////////////Analysis////////////////////////////////////////////////////////////

	//Set the background color to black otherwise this messes with the clear outside command
	setBackgroundColor(0,0,0);
		
	//Set the path to where we copy our analysed cells to so we can run a fractal analysis on this folder in 
	//batch at a later timepoint - if this directory doesn't exist, make it
	fracLacPath = directories[1]+"fracLac/";

	iniTextValuesMicrons = newArray(5);
	getIniData(directoryName, iniTextValuesMicrons);
	
	if(File.exists(fracLacPath)==0) {
		File.makeDirectory(fracLacPath);
	}
	
	loopThrough = getFileList(directories[1]);

	for(i=0; i<loopThrough.length; i++) {
	
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

			//Get out the average value of whether we've analysed each TCS or not (where 1 = true and 0 = false)
			//so that if our mean value isn't 1, it means we've not analysed all TCS values, else we have
			selectWindow("TCS Status.csv");
			aCol = Table.getColumn("Analysed");
			Array.getStatistics(aCol, aMin, aMax, aMean, aSD);
			selectWindow("TCS Status.csv");
			Table.reset("TCS Status.csv");
			
			//If we haven't analysed all TCS levels already
			if(aMean!=1) {
				
				//Clear results table just to be sure
				run("Clear Results");
				
				//Fill TCS Status table with its existing/previous values
				TCSColumns = newArray("TCS", "Masks Generated", "QC Checked", "Analysed");
				TCSValues = newArray(numberOfLoops*TCSColumns.length);
				
				//First numberOfLoops indices are TCS, then Masks Generated etc.
				TCSResultsRefs = newArray(directories[1]+imageNames[3]+"/TCS Status.csv", directories[1]+imageNames[3]+"/TCS Status.csv", 
											directories[1]+imageNames[3]+"/TCS Status.csv", directories[1]+imageNames[3]+"/TCS Status.csv");
				TCSResultsAreStrings = newArray(false, false, false, false);
			
				fillArray(TCSValues, TCSResultsRefs, TCSColumns, TCSResultsAreStrings, true); 
	
				Table.create("TCS Status");
				selectWindow("TCS Status");
				for(i0=0; i0<numberOfLoops; i0++) {
					for(i1=0; i1<TCSColumns.length; i1++) {
						Table.set(TCSColumns[i1], i0, TCSValues[(numberOfLoops*i1)+i0]);
					}
				}
				
				//Loop through the number of TCS loops we need to do
				for(TCSLoops=0; TCSLoops<numberOfLoops; TCSLoops++) {
			
					selectWindow("TCS Status");
					currentLoopValues = newArray(TCSColumns.length);
					//[0] is TCS, [1] is masks generated, [2] is QC checked, [3] is analysed

					currentLoopValues[0] = Table.get("TCS", TCSLoops);
			
					selectWindow("TCS Status");
					for(i0 = 0; i0<Table.size; i0++) {
						if(currentLoopValues[0] == Table.get("TCS", i0)) {
							//Here we fill our currentLoopValues table with the TCSValues data that corresponds to the TCS value
							//we're current processing - this will be a bunch of zeros if we haven't processed anything before
							for(i1=0; i1<TCSColumns.length; i1++) {
								currentLoopValues[i1] = Table.get(TCSColumns[i1], i0);
							}
							i0 = Table.size;
						}
					}
									
					if(currentLoopValues[2] == 1 && currentLoopValues[3] == 0) {

						//Set the directory for the current TCS value
						TCSDir=directories[1]+imageNames[3]+"/"+"TCS"+currentLoopValues[0]+"/";
				
						//Store the directories we'll refer to for the listed properties of the cells and fill it
						storageFoldersArray=newArray(storageFolders.length);
						//[0] is cell coords, [1] is cell coordinates masks, [2] is somas, [3] is maskDir, [4] is localregion
						//[5] is results
						
						for(i0=0; i0<storageFolders.length; i0++) {
							if(i0<3) {
								parentDir=directories[1]+imageNames[3]+"/";	
							} else {
								parentDir=TCSDir;	
							}
							storageFoldersArray[i0]=parentDir+storageFolders[i0];
						}
				
			
						//If the results folder doesn't exist yet, make it
						if(File.exists(storageFoldersArray[5])==false) {
								File.makeDirectory(storageFoldersArray[5]);
						}

						somaFiles = getFileList(storageFoldersArray[2]);
			
						//Get the list of cell masks present
						maskDirFiles = getFileList(storageFoldersArray[3]);
			
						//oldParams is a list of the parameters we measure using the normal measurements function in
						//imageJ
						oldParams = newArray("Analysed", "Perimeter", "Cell Spread", "Eccentricity", 
													"Roundness", "Soma Size", "Mask Size"); 

						//skelNames is a list of the parameters we measure on a skeletonised image in imageJ
						skelNames = newArray("# Branches", "# Junctions", "# End-point voxels", "# Junction voxels", 
						"# Slab voxels", "Average Branch Length", "# Triple points", "# Quadruple points", 
						"Maximum Branch Length", "Longest Shortest Path", "SkelArea");

						valuesToRecord = Array.concat(oldParams, skelNames);
			
						analysisRecordInput = newArray(maskDirFiles.length*valuesToRecord.length);
						//First maskDirFiles.length indices are "Analysed", then "Keep", etc

						//Fill analysisRecordInput appropriately
						resultsTableRefs = newArray(valuesToRecord.length);
						resultsAreStrings = newArray(valuesToRecord.length);
						for(i0 = 0; i0<valuesToRecord.length; i0++) {
							resultsTableRefs[i0] = TCSDir + "Cell Parameters.csv";
							resultsAreStrings[i0] = false;
						}
			
						fillArray(analysisRecordInput, resultsTableRefs, valuesToRecord, resultsAreStrings, true);

						//Fill an array of whether each cell passed the QC control or not
						imagesKept = newArray(maskDirFiles.length);
						fillArray(imagesKept, TCSDir+"QC Checked.csv", "Keep", true, false);
			
						//Get values for the substack location, experiment (animal and timepoint), as well as the TCS value,
						//cellName, and whether we used the wrong Objective settings, add these to the analysisRecordInput
						//array
						substackLoc = newArray(maskDirFiles.length);
						for(i0 = 0; i0<substackLoc.length; i0++) {
							substackLoc[i0] = substring(maskDirFiles[i0], indexOf(toLowerCase(maskDirFiles[i0]), "substack"), indexOf(maskDirFiles[i0], "x")); 
						}
						
						experimentName = newArray(maskDirFiles.length);
						cellName = newArray(maskDirFiles.length);
						for(i0=0; i0<maskDirFiles.length; i0++) {
							experimentName[i0] = imageNames[3];
							cellName[i0] = substring(maskDirFiles[i0], indexOf(maskDirFiles[i0], "x"), indexOf(maskDirFiles[i0], ".tif")); 
						}
						
						TCSForParameters=newArray(maskDirFiles.length);
						Array.fill(TCSForParameters, currentLoopValues[0]);
						//cellName=Array.copy(maskDirFiles);
						
						analysisRecordInput = Array.concat(analysisRecordInput, substackLoc);
						analysisRecordInput = Array.concat(analysisRecordInput, experimentName);
						analysisRecordInput = Array.concat(analysisRecordInput, TCSForParameters);
						analysisRecordInput = Array.concat(analysisRecordInput, cellName);
			
						//Fill our cell parameters with all this concatenated data and the names for it all
						toAdd = newArray("Stack Position", "Experiment Name", "TCS", "Cell Name");
						tableLabels = Array.concat(valuesToRecord, toAdd);
			
						Table.create("Cell Parameters");
						selectWindow("Cell Parameters");

						rowToAdd = 0;
						
						//Loop through the input files
						for(i0=0; i0<maskDirFiles.length; i0++) {
				
							currentMaskValues = newArray(7);
							//[0] is analysed, [1] is perimeter, [2] is cell spread, [3] is eccentricity, [4] is roundness,
							//[5] is soma size, [6] is mask area
					
							//Fill with existing values
							for(i1=0; i1<currentMaskValues.length; i1++) {
								currentMaskValues[i1] = analysisRecordInput[(maskDirFiles.length*i1)+i0];
							}
			
							//If we haven't analysed the image yet and we're keeping it (acc. to QC), then we enter here

							if(imagesKept[i0] == 1 && currentMaskValues[0] == 0) {

								print(maskDirFiles[i0]);
								
								//If we haven't already copied the cell to the fracLac folder, do so
								if(File.exists(fracLacPath + "TCS" + toString(currentLoopValues[0]) +  imageNames[0] + maskDirFiles[i0]) == 0) {
									File.copy(storageFoldersArray[3] + maskDirFiles[i0], fracLacPath + "TCS" + toString(currentLoopValues[0]) +  imageNames[0] + maskDirFiles[i0]);
								}
								
								//Get out our skeleton values
								open(storageFoldersArray[3] + maskDirFiles[i0]);
								getDimensions(maskWidth, maskHeight, maskChannels, maskSlices, maskFrames);

								//Set calibration to pixels
								run("Properties...", "channels="+maskChannels+" slices="+maskSlices+" frames="+maskFrames+" unit=pixels pixel_width=1 pixel_height=1 voxel_depth=1");
								rename("Test");

								run("Clear Results");
								
								//Skeletonise the image then get out the measures associated with the skelNames array from earlier
								run("Duplicate...", " ");
								run("Invert");
								run("Skeletonize (2D/3D)");
								run("Analyze Skeleton (2D/3D)", "prune=[shortest branch] calculate");
								
								//If we're getting out length, we measure the number of pixels in the skeleton
								storeValues = newArray(skelNames.length);
								for(i1 = 0; i1< skelNames.length; i1++) {
									if(i1 < skelNames.length-1) {
									storeValues[i1] = getResult(skelNames[i1], 0);
									} else {
										selectWindow("Test-1");
										run("Invert");
										run("Create Selection");
										getRawStatistics(nPixels);
										storeValues[i1] = nPixels;
										run("Select None");
									}
								}
								run("Clear Results");

								//Close images we don't need anymore
								toClose = newArray("Longest shortest paths", "Tagged skeleton", "Test-1");
								for(i1 = 0; i1< toClose.length; i1++) {
									if(isOpen(toClose[i1])==1) {
									selectWindow(toClose[i1]);
									run("Close");
									}
								}
								
								//Select our non skeletonised image, get its perim, circul, AR, and area
								selectWindow("Test");
								rename(maskDirFiles[i0]);
								run("Create Selection");
								roiManager("add");
								List.setMeasurements;
			
								resultsStrings = newArray("Perim.", "Circ.", "AR", "Area");
								currentLoopIndices = newArray(1,4,3,6);
			
								for(i1=0; i1<resultsStrings.length; i1++) {
									currentMaskValues[(currentLoopIndices[i1])] = List.getValue(resultsStrings[i1]);
								}
			
								run("Select None");
								run("Invert");
								run("Points from Mask");
					
								//This bit is used to calculate the leftmost, rightmost, bottommost, and topmost parts of the mask
								//We then calculate the average distance between the centre of mass of the mask and these points
								//for our measure of cell spread
			
								//Get the selection coordinates of our mask
								getSelectionCoordinates(x, y);
			
								Array.getStatistics(x, xMin, xMax, mean, stdDev);
								Array.getStatistics(y, yMin, yMax, mean, stdDev);
			
								valuesToMatch = newArray(xMax, xMin, yMax, yMin);
			
								xAndYPoints = newArray(xMax, 0, xMin, 0, 0, yMax, 0, yMin);
								//[0] and [1] are highest x with y (rightmost), [2] and [3] are lowest x with y (leftmost), 
								//[4] and [5] are x and highest y (topmost) [7] and [8] are x with lowest y (bottommost)
			
								for(i1=0; i1<valuesToMatch.length; i1++) {	
									associatedValues = newArray(1);
									arrayToConcat = newArray(1);
									for(i2=0; i2<x.length; i2++) {
										matched = false;
										if(i1<2) {
											if(x[i2] == valuesToMatch[i1]) {
												associatedValues[associatedValues.length-1] = y[i2];
												matched = true;
											}
										} else {
											if(y[i2] == valuesToMatch[i1]) {
												associatedValues[associatedValues.length-1] = x[i2];
												matched = true;
											}
										}
										if(matched == true){
											//setBatchMode("exit and display");
											//Array.show("test", associatedValues);
											//waitForUser("");
											associatedValues = Array.concat(associatedValues, arrayToConcat);
										}	
									}
			
									finalList = newArray(1);
									finalList = removeZeros(associatedValues, finalList);
									
									Array.getStatistics(finalList, asMin, asMax, asMean, asStdDev);
			
									if(i1<2) {
										xAndYPoints[(i1*2)+1] = round(asMean);
									} else {
										xAndYPoints[(i1*2)] = round(asMean);
									}
								}
							
								open(storageFoldersArray[4]+"Local region for "+ substring(maskDirFiles[i0], indexOf(maskDirFiles[i0],"Substack")));
								LRImage = getTitle();
								selectWindow(LRImage);
								getDimensions(LRwidth, LRheight, LRchannels, LRslices, LRframes);
					
								//Calibrate to pixels so we can get the right values when we make points on our image as the previously generated variables are all
								//calibrated in pixels
								selectWindow(LRImage);
								run("Properties...", "channels="+LRchannels+" slices="+LRslices+" frames="+LRframes+" unit=pixels pixel_width=1 pixel_height=1 voxel_depth=1");
								roiManager("select", 0);
								List.setMeasurements;
			
								resultsStrings = newArray("XM", "YM");
								centresOfMass = newArray(2);
			
								for(i1=0; i1<resultsStrings.length; i1++) {
									centresOfMass[i1] = List.getValue(resultsStrings[i1]);
								}
			
								run("Select None");
								distances = newArray(4);
								//[0] is distance to the right, [1] is to the left, [2] is the top, [3] is the bottom
			
								for(i1=0; i1<4; i1++) {
									xToCheck = xAndYPoints[(i1*2)];
									yToCheck = xAndYPoints[(i1*2)+1];
			
									xDistance = abs(xToCheck-centresOfMass[0]);
									yDistance = abs(yToCheck-centresOfMass[1]);
			
									distances[i1] = sqrt((pow(xDistance,2) + pow(yDistance,2)));
			
									makeLine(centresOfMass[0], centresOfMass[1],  xAndYPoints[(i1*2)], xAndYPoints[(i1*2)+1]);
									Roi.setStrokeColor("red");
									roiManager("add");
								}
			
								//Store the average distance from the centre of mass to the xtremeties
								Array.getStatistics(distances, disMin, disMax, disMean, disStdDev);
								currentMaskValues[2] = disMean;
								
								run("Select None");
					
								//This is saving an image to show where the lines and centre are
								selectWindow(LRImage);
								run("Properties...", "channels="+LRchannels+" slices="+LRslices+" frames="+LRframes+" unit=um pixel_width="+iniTextValuesMicrons[0]+" pixel_height="+iniTextValuesMicrons[1]+" voxel_depth="+iniTextValuesMicrons[2]+"");
								roiManager("show all without labels");
								run("Flatten");
								selectWindow(LRImage);
								saveAs("tiff", storageFoldersArray[5]+"Extrema for "+ substring(maskDirFiles[i0], indexOf(toLowerCase(maskDirFiles[i0]), "substack")));
					
								//Here we open the soma mask for the cell in question, and get its size
								oldxCoord = parseInt(substring(maskDirFiles[i0], indexOf(maskDirFiles[i0], "x ")+2, indexOf(maskDirFiles[i0], "y")-1));
								oldyCoord = parseInt(substring(maskDirFiles[i0], indexOf(maskDirFiles[i0], "y ")+2, indexOf(maskDirFiles[i0], ".tif")-1));
								oldSubstackLoc = substring(maskDirFiles[i0], indexOf(maskDirFiles[i0], "Substack"), indexOf(maskDirFiles[i0], "x"));
								adjustBy = newArray(0,0);
								if(File.exists(storageFoldersArray[2]+"Candidate Soma Mask for "+ substring(maskDirFiles[i0], indexOf(toLowerCase(maskDirFiles[i0]), "substack")))==0) {
									//waitForUser("doesn't exist");
									for(i1 = 0; i1<somaFiles.length; i1++) {
										newxCoord = parseInt(substring(somaFiles[i1], indexOf(somaFiles[i1], "x ")+2, indexOf(somaFiles[i1], "y")-1));
										newyCoord = parseInt(substring(somaFiles[i1], indexOf(somaFiles[i1], "y ")+2, indexOf(somaFiles[i1], ".tif")-1));
										newsubstackLoc = substring(somaFiles[i1], indexOf(somaFiles[i1], "Substack"), indexOf(somaFiles[i1], "x"));
										if(abs(oldxCoord-newxCoord) <= 10 && abs(oldyCoord-newyCoord) <= 10 && newsubstackLoc == oldSubstackLoc) {
											adjustBy[0] = newxCoord-oldxCoord;
											adjustBy[1] = newyCoord-oldyCoord;
											//print(maskDirFiles[i0]);
											//print(somaFiles[i1]);
											open(storageFoldersArray[2] + somaFiles[i1]);
										}
									}
								} else {
									open(storageFoldersArray[2]+"Candidate Soma Mask for "+ substring(maskDirFiles[i0], indexOf(toLowerCase(maskDirFiles[i0]), "substack")));
								}
								rename("Soma");
								run("Properties...", "channels="+LRchannels+" slices="+LRslices+" frames="+LRframes+" unit=pixels pixel_width=1 pixel_height=1 voxel_depth=1");
								run("Create Selection");
								List.setMeasurements;
			
								resultsToGet = newArray("Area", "XM", "YM");
								resultsToOutput = newArray(3);
								//[0] is soma area, [1] is xMass, [2] is yMass
		
								for(i1=0; i1<3; i1++) {
									resultsToOutput[i1] = List.getValue(resultsToGet[i1]);
									//print(resultsToOutput[i1]);
								}
		
								currentMaskValues[5] = resultsToOutput[0];
					
								//We then find the centre of mass of the soma, and the radius of the soma (on average)
								//so that we can use the point and the radius to calculate a sholl analysis on the cell masks
								//starting from the edge of the soma
								//startradius=sqrt((currentMaskValues[5]*(iniTextValuesMicrons[1]/PI);
		
								startradius=sqrt((currentMaskValues[5]*pow(iniTextValuesMicrons[1], 2))/PI);
					
								//Here we run the sholl analysis using the point, the radius, and ending at the ending radius of the local region
								//We also output all the semi-log, log-log, linear, and linear-norm plots of the number of intersections at various distances
								//The normalisation is done using the area of the mask
								//Results are saved in the results folder
								roiManager("show none");
			
								selectWindow(maskDirFiles[i0]);
								run("Select None");
								makePoint(resultsToOutput[1]+adjustBy[0], resultsToOutput[2]+adjustBy[1]);

								//if(adjustBy[0] != 0 || adjustBy[1] != 0) {
									//print(resultsToOutput[1], resultsToOutput[2]);
									//print(adjustBy[0], adjustBy[1]);
									//setBatchMode("exit and display");
									//waitForUser("");
									//setBatchMode(true);
								//}
								
								run("Properties...", "channels="+maskChannels+" slices="+maskSlices+" frames="+maskFrames+" unit=um pixel_width="+iniTextValuesMicrons[0]+" pixel_height="+iniTextValuesMicrons[1]+" voxel_depth="+iniTextValuesMicrons[2]+"");
								run("Sholl Analysis...", "starting="+startradius+" ending="+LRSize+" radius_step=0 enclosing=1 #_primary=0 infer fit linear polynomial=[Best fitting degree] linear-norm semi-log log-log normalizer=Area create save directory=["+storageFoldersArray[5]+"] do");

								saveAs("Results", storageFoldersArray[5]+substring(maskDirFiles[i0], indexOf(toLowerCase(maskDirFiles[i0]), "substack"), indexOf(maskDirFiles[i0], ".tif")) + ".csv");
								selectWindow(substring(maskDirFiles[i0], indexOf(toLowerCase(maskDirFiles[i0]), "substack"), indexOf(maskDirFiles[i0], ".tif")) + ".csv");
								run("Close");
								run("Clear Results");
			
								Housekeeping();
		
						
								//Set the fact we've analysed the cell to 1 (true)
								currentMaskValues[0] = 1;

								//Concatenate the measured values together, with the info about the cell
								newValsOne = Array.concat(currentMaskValues, storeValues);
								toAdd = newArray(substackLoc[i0], imageNames[3], currentLoopValues[0], cellName[i0]);
								newVals = Array.concat(newValsOne, toAdd);

								//Here we update and save our cell parameters table
								selectWindow("Cell Parameters");
								for(i1 = 0; i1<tableLabels.length; i1++) {
									if(i1 == 18 || i1 == 19 || i1 == 21) {
										stringValue = newVals[i1];
										Table.set(tableLabels[i1], rowToAdd, stringValue);
									} else if (i1==1 || i1==2 || i1 == 12 || i1 == 15 || i1 == 16) {
										numberToStore = newVals[i1] * iniTextValuesMicrons[0];
										Table.set(tableLabels[i1], rowToAdd, numberToStore);
									} else if (i1==5 || i1==6 || i1 == 17) {
										numberToStore = newVals[i1] * pow(iniTextValuesMicrons[0],2);
										Table.set(tableLabels[i1], rowToAdd, numberToStore);
									} else {
										Table.set(tableLabels[i1], rowToAdd, newVals[i1]);
									}
								}
								Table.update;
								rowToAdd++;
							
							}	
						
						}	
		
						//Indicate that this TCS has been analysed
						currentLoopValues[3] = 1;
			
						//Update and save our TCS analysis table
						selectWindow("TCS Status");
						for(i0=0; i0<TCSColumns.length; i0++) {
							Table.set(TCSColumns[i0], TCSLoops, currentLoopValues[i0]);
						}
		
						selectWindow("Cell Parameters");
						Table.update;
						Table.save(TCSDir+"Cell Parameters.csv");
						currParam = Table.title;
						Table.rename(currParam, "Cell Parameters");
						
					}
			
				}

				selectWindow("TCS Status");
				Table.save(directories[1]+imageNames[3]+"/TCS Status.csv");
				currTCSTitle = Table.title;
				Table.rename(currTCSTitle, "TCS Status");
			
			}
		}
	}
}
print("Morphological analysis complete");