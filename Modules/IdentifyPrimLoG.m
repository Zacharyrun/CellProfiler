function handles = IdentifyPrimLoG(handles)

% Help for the Identify Primary LoG module:
% Category: Object Processing
%
% SHORT DESCRIPTION:
%
% Identifies the centers of blob-like primary objects.  The result
% consists of only a single pixel per object, located near the center
% of the object.
%
% *************************************************************************
%
% This module identifies the centers of blob-like primary objects
% (e.g. nuclei) in grayscale images that show bright objects on a dark
% background.  When the objects of interest are fairly round and of
% even size, this module may be more sensitive than the methods in
% IdentifyPrimAutomatic and therefore detect objects that would
% otherwise be lost.
% 
% The result consists of only a single pixel per object, located near
% the center of the object; the IdentifySecondary module can be used
% to fill out the object based on this center point.
%
% SETTINGS:
%
% The radius parameter should be set to the approximate radius of the
% objects of interest.  The algorithm is not very sensitive to this
% parameter.
%
% The threshold parameter tells the algorithm how inclusive to be when
% looking for objects.  Internally, each potential object is assigned
% a score that depends on both how bright the object is and how
% blob-like its shape is.  Only objects that score above the threshold
% are returned.  The threshold must be determined experimentally, but 
% the 'Automatic' setting will make a guess using Otsu's thresholding 
% method on the transformed image.  If you want the threshold to be 
% consistent across images, then use the threshold found by the 'Automatic'
% setting as a starting point for manual threshold input adjustment.  
% If the thresold is too high, objects will be lost; 
% if it is too low, spurious objects will be found.
%
% ALGORITHM DETAILS:
%
% The module works by convolving the image with the Laplacian of
% Gaussian (LoG) kernel.  This is equivalent to convolving with the
% Gaussian kernel and then with the Laplace operator.  The regional
% maxima in the filter response that exceed the specificed threshold
% are identified as objects.  The radius parameter specifies the width
% of the kernel.
%
% Ultimately, this module will become an option in
% IdentifyPrimAutomatic, so that its options for maxima suppression
% and finding edges between clumps can be used.
%
% $Revision$

%%%%%%%%%%%%%%%%%
%%% VARIABLES %%%
%%%%%%%%%%%%%%%%%

% Notes for PyCP
%
% FROM CP ToDo:
% Anne 2008_01_30: Merge IdentifyPrimaryLoG into the regular IdentifyPrimAutomatic module. 
% In particular, be sure that the help describes under what conditions the different options 
% are useful. Think carefully about how to add the variable that is LoG-specific to the module.
%
% Anne 2008_05_12: Describe what the LoG is doing - we think that we are looking for 
% minima (or maxima) of the LoG which makes it a maxima-minima finder of the original image, 
% whereas many people look for zero crossings of the LoG which would be using it as an edge 
% detector. Is that right?
%
% David 2009_04_17:  As the above older comments say, this module should be integrated into
% IDPrimAuto.  However, this ID module is different than other primary segmentation modules
% in that it only finds the center pixel of objects and must utilize a subsequent IDSecondary 
% after to grow objects.  So we either:
% (1) Treat LoG as a special thresholding method that only ouputs single pixel objects
% or
% (2) Treat LoG as a declumping method.  In this case, another thresholding method would define 
% foreground/background, and LoG would find single pixels within the foreground.
% 
% In either case, we would need to decide whether we automatically apply a watershed/propagation
% after the initial single-pixel finding method.  I prefer (2) above and would opt for
% automatically propagating the single-pixels within the foreground objects, since that is almost 
% always done anyway, and would save the step of adding an IDSecondary.
%
% Settings:
% The first two settings map obviously.
% The diameter parameter is only single, so that if LoG is chosen, one of the diameter boxes 
% should gray-out.
% The threshold parameter is very sensitive, and the user was blind to what this should be at first,
% so the 'Automatic' threshold was added recently to use Otsu to guess.  This functionality would be
% equivalent to the 'Automatic' setting in the existing declumping settings.

drawnow

[CurrentModule, CurrentModuleNum, ModuleName] = CPwhichmodule(handles);

%textVAR01 = What did you call the images you want to process?
%infotypeVAR01 = imagegroup
ImageName = char(handles.Settings.VariableValues{CurrentModuleNum,1});
%inputtypeVAR01 = popupmenu

%textVAR02 = What do you want to call the objects identified by this module?
%defaultVAR02 = Nuclei
%infotypeVAR02 = objectgroup indep
ObjectName = char(handles.Settings.VariableValues{CurrentModuleNum,2});

%textVAR03 = Typical diameter of objects, in pixel units:
%defaultVAR03 = 10
Radius = char(handles.Settings.VariableValues{CurrentModuleNum,3});

%textVAR04 = Score threshold for match.  Enter a number, or leave as 'Automatic'.
%defaultVAR04 = Automatic
Threshold = char(handles.Settings.VariableValues{CurrentModuleNum,4});

%%%VariableRevisionNumber = 1

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% PRELIMINARY ERROR CHECKING & FILE HANDLING %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
drawnow

OrigImage = double(CPretrieveimage(handles,ImageName,ModuleName,'MustBeGray','CheckScale'));
Radius = str2double(Radius);

%%%%%%%%%%%%%%%%%%%%%%
%%% IMAGE ANALYSIS %%%
%%%%%%%%%%%%%%%%%%%%%%
drawnow

im = double(OrigImage) - double(min(OrigImage(:)));
if any(im(:))
    im = im / max(im(:));
end

% Set regions outside of CropMasks equal to 0
fieldname = ['CropMask', ImageName];
if CPisimageinpipeline(handles, fieldname)
    %%% Retrieves previously selected cropping mask from handles
    %%% structure.
    try 
        im(~CPretrieveimage(handles,fieldname,ModuleName)) = 0;
    catch
        error('The image in which you want to identify objects has been cropped, but there was a problem recognizing the cropping pattern.');
    end
end

ac = lapofgau(1 - im, Radius);

if strcmpi('Automatic',Threshold)
    [handles,Threshold] = CPthreshold(handles,'Otsu Global',0.5,'0','1',1,ac,'LoG',ModuleName);
% elseif strcmpi('Set interactively',Threshold)
%     Threshold = CPthresh_tool(ac); %% Need to scale better?
else
    Threshold = str2double(Threshold);
end

ac(ac < Threshold) = Threshold;
ac = ac - Threshold;
indices = find(imregionalmax(ac));
maxima = sortrows([indices ac(indices)], -2);

bw = false(size(im));
bw(maxima(:,1)) = true;
FinalLabelMatrixImage = bwlabel(bw);

% The dilated mask is used only for visualization.
dilated = imdilate(bw, strel('disk', 2));
vislabel = bwlabel(dilated);
r = im;
g = im;
b = im;
r(dilated) = 1;
g(dilated) = 0;
b(dilated) = 0;
visRGB = cat(3, r, g, b);

%%%%%%%%%%%%%%%%%%%%%%%
%%% DISPLAY RESULTS %%%
%%%%%%%%%%%%%%%%%%%%%%%
drawnow

ThisModuleFigureNumber = handles.Current.(['FigureNumberForModule',CurrentModule]);
if any(findobj == ThisModuleFigureNumber)
  h_fig = CPfigure(handles,'Image',ThisModuleFigureNumber);
  [hImage,hAx] = CPimagesc(visRGB, handles,ThisModuleFigureNumber);
  title(hAx,[ObjectName, ' cycle # ',num2str(handles.Current.SetBeingAnalyzed)]);
  
  uicontrol(h_fig,'units','normalized','position',[.01 .5 .06 .04],'string','off',...
      'UserData',{OrigImage visRGB},'backgroundcolor',[.7 .7 .9],...
      'Callback',@CP_OrigNewImage_Callback);
  
  text(0.1,-0.08,...
      ['Threshold: ' num2str(Threshold)],...
      'Color','black',...
      'fontsize',handles.Preferences.FontSize,...
      'Units','Normalized',...
      'Parent',hAx);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% SAVE DATA TO HANDLES STRUCTURE %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
drawnow

prefixes = {'Segmented', 'SmallRemovedSegmented'};
for i=1:length(prefixes)
  prefix = prefixes{i};
  fieldname = [prefix, ObjectName];
  handles = CPaddimages(handles,fieldname,FinalLabelMatrixImage);
end

handles = CPsaveObjectCount(handles, ObjectName, FinalLabelMatrixImage);
handles = CPsaveObjectLocations(handles, ObjectName, FinalLabelMatrixImage);

function f = lapofgau(im, s)
% im: image matrix (2 dimensional)
% s: filter width
% f: filter output.
% Author: Baris Sumengen - sumengen@ece.ucsb.edu

sigma = (s-1)/3;
op = fspecial('log',s,sigma); 
op = op - sum(op(:))/numel(op); % make the op to sum to zero
f = filter2(op,im);
