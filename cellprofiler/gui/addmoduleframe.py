"""AddModuleFrame.py - this is the window frame and the subwindows
that give you the GUI to add a module to a pipeline

CellProfiler is distributed under the GNU General Public License.
See the accompanying file LICENSE for details.

Developed by the Broad Institute
Copyright 2003-2010

Please see the AUTHORS file for credits.

Website: http://www.cellprofiler.org
"""
__version = "$Revision$"
import os
import re
import wx
import cellprofiler.preferences
import cellprofiler.modules
import cellprofiler.cpmodule
from cellprofiler.gui import get_icon
from cellprofiler.gui.help import BUILDING_A_PIPELINE_HELP
import cpframe

class AddModuleFrame(wx.Frame):
    """The window frame that lets you add modules to a pipeline
    
    """
    def __init__(self, *args, **kwds):
        """Initialize the frame and its layout
        
        """
        kwds["style"] = wx.DEFAULT_FRAME_STYLE
        wx.Frame.__init__(self, *args, **kwds)
        self.SetSize(wx.Size(425, 360))
        # Top level panels
        left_panel = wx.Panel(self,-1)
        right_panel = wx.Panel(self,-1)
        self.SetBackgroundColour(left_panel.GetBackgroundColour())
        # Module categories (in left panel)
        module_categories_text = wx.StaticText(left_panel,-1,'Module Categories',style=wx.ALIGN_CENTER)
        font = module_categories_text.GetFont()
        module_categories_text.SetFont(wx.Font(font.GetPointSize()*1.2,font.GetFamily(),font.GetStyle(),wx.FONTWEIGHT_BOLD))
        self.__module_categories_list_box = wx.ListBox(left_panel,-1)
        # Control panel for the selected module
        selected_module_panel = wx.Panel(left_panel,-1)
        selected_module_static_box = wx.StaticBox(selected_module_panel,-1,'For Selected Module')
        add_to_pipeline_button = wx.Button(selected_module_panel,-1,'+ Add to Pipeline')
        module_help_button = wx.Button(selected_module_panel,-1,'? Module Help')
        # Other buttons
        getting_started_button = wx.Button(left_panel,-1,'Getting Started')
        wheres_my_module_button = wx.Button(left_panel,-1,'Where''s my Module?')
        browse_button = wx.Button(left_panel,-1,'Browse...')
        done_button = wx.Button(left_panel,-1,'Done')
        # Right-side panel
        self.__module_list_box = wx.ListBox(right_panel,-1)
        # Sizers
        top_sizer = wx.BoxSizer(wx.HORIZONTAL)
        top_sizer.AddMany([(left_panel,0,wx.EXPAND|wx.LEFT,5),
                           (right_panel,1,wx.EXPAND)])
        self.SetSizer(top_sizer)
        left_sizer = wx.BoxSizer(wx.VERTICAL)
        left_sizer.Add(module_categories_text,0,wx.EXPAND)
        left_sizer.AddSpacer(4)
        left_sizer.Add(self.__module_categories_list_box,1,wx.EXPAND)
        left_sizer.AddSpacer((-1,10))
        left_sizer.Add(selected_module_panel,0,wx.EXPAND)
        left_sizer.AddSpacer((-1,10))
        left_sizer.Add(getting_started_button,0,wx.EXPAND)
        left_sizer.AddSpacer(2)
        left_sizer.Add(wheres_my_module_button,0,wx.EXPAND)
        left_sizer.AddSpacer(2)
        left_sizer.Add(browse_button,0,wx.EXPAND)
        left_sizer.AddSpacer(2)
        left_sizer.Add(done_button,0,wx.EXPAND |wx.BOTTOM,5)
        left_panel.SetSizer(left_sizer)
        
        right_sizer = wx.BoxSizer(wx.VERTICAL)
        right_sizer.Add(self.__module_list_box,1,wx.EXPAND|wx.ALL,5)
        right_panel.SetSizer(right_sizer)
        
        selected_module_panel_sizer = wx.StaticBoxSizer(selected_module_static_box,wx.VERTICAL)
        selected_module_panel_sizer.Add(add_to_pipeline_button,0,wx.EXPAND)
        selected_module_panel_sizer.AddSpacer(2)
        selected_module_panel_sizer.Add(module_help_button,0,wx.EXPAND)
        selected_module_panel.SetSizer(selected_module_panel_sizer)
        
        self.__set_icon()
        accelerators = wx.AcceleratorTable(
            [(wx.ACCEL_CMD, ord('W'), cpframe.ID_FILE_EXIT)])
        self.SetAcceleratorTable(accelerators)
        
        self.Bind(wx.EVT_CLOSE,self.__on_close, self)
        self.Bind(wx.EVT_LISTBOX,self.__on_category_selected,self.__module_categories_list_box)
        self.Bind(wx.EVT_LISTBOX_DCLICK, self.__on_add_to_pipeline,self.__module_list_box)
        self.Bind(wx.EVT_BUTTON,self.__on_add_to_pipeline,add_to_pipeline_button)
        self.Bind(wx.EVT_BUTTON,self.__on_close,done_button)
        self.Bind(wx.EVT_BUTTON,self.__on_help, module_help_button)
        self.Bind(wx.EVT_BUTTON,self.__on_getting_started, getting_started_button)
        self.Bind(wx.EVT_BUTTON,self.__on_wheres_my_module, wheres_my_module_button)
        self.Bind(wx.EVT_MENU, self.__on_close, id=cpframe.ID_FILE_EXIT)
        self.__get_module_files()
        self.__set_categories()
        self.__listeners = []
        self.__module_categories_list_box.Select(0)
        self.__on_category_selected(None)
        self.Layout()
        
    def __on_close(self,event):
        self.Hide()
        
    def __set_icon(self):
        icon = get_icon()
        self.SetIcon(icon)
        
    def __get_module_files(self):
        self.__module_files = [ 'File Processing',
                                'Image Processing',
                                'Object Processing',
                                'Measurement',
                                'Data Tools',
                                'Other',
                                'All'
                               ]
        self.__module_dict = {}
        for key in self.__module_files:
            self.__module_dict[key] = {}
            
        for mn in cellprofiler.modules.get_module_names():
            def loader(module_num, mn=mn):
                module = cellprofiler.modules.instantiate_module(mn)
                module.set_module_num(module_num)
                return module
            module = cellprofiler.modules.instantiate_module(mn)
            self.__module_dict[module.category][module.module_name] = loader
            self.__module_dict['All'][module.module_name] = loader
    
    def __set_categories(self):
        self.__module_categories_list_box.AppendItems(self.__module_files)
        
    def __on_category_selected(self,event):
        category=self.__get_selected_category()
        self.__module_list_box.Clear()
        keys = self.__module_dict[category].keys()
        keys.sort()
        self.__module_list_box.AppendItems(keys)
        self.__module_list_box.Select(0)

    def __get_selected_category(self):
        return self.__module_files[self.__module_categories_list_box.GetSelection()]

    def __on_add_to_pipeline(self,event):
        category = self.__get_selected_category()
        idx = self.__module_list_box.GetSelection()
        if idx != wx.NOT_FOUND:
            file = self.__module_list_box.GetItems()[idx]
            self.notify(AddToPipelineEvent(file,self.__module_dict[category][file]))
    
    def __on_help(self,event):
        category = self.__get_selected_category()
        idx = self.__module_list_box.GetSelection()
        if idx != wx.NOT_FOUND:
            file = self.__module_list_box.GetItems()[idx]
            loader = self.__module_dict[category][file]
            module = loader(0)
            if isinstance(self.Parent,cpframe.CPFrame):
                self.Parent.do_help_module(module.module_name, module.get_help())
            else:
                help = module.get_help()
                wx.MessageBox(help)
                
    def __on_getting_started(self,event):
        helpframe = wx.Frame(self,-1,'Add modules: Getting Started',size=(640,480))
        sizer = wx.BoxSizer()
        helpframe.SetSizer(sizer)
        window = wx.html.HtmlWindow(helpframe)
        sizer.Add(window,1,wx.EXPAND)
        window.AppendToPage(BUILDING_A_PIPELINE_HELP)
        helpframe.SetIcon(get_icon())
        helpframe.Layout()
        helpframe.Show()
               
    def __on_wheres_my_module(self,event):
        import webbrowser
        webbrowser.open("http://cellprofiler.org/forum/viewtopic.php?f=14&t=806&p=3221")
                
    def add_listener(self,listener):
        self.__listeners.append(listener)
        
    def remove_listener(self,listener):
        self.__listeners.remove(listener)
    
    def notify(self,event):
        for listener in self.__listeners:
            listener(self,event)

class AddToPipelineEvent(object):
    def __init__(self,module_name,module_loader):
        self.module_name = module_name
        self.__module_loader = module_loader
    
    def get_module_loader(self):
        """Return a function that, when called, will produce a module
        
        The function takes one argument: the module number
        """
        return self.__module_loader
    
    module_loader = property(get_module_loader)