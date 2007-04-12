Xinha.version={"Release":"Trunk","Head":"$HeadURL: http://svn.xinha.python-hosting.com/tags/0.92beta/XinhaCore.js $".replace(/^[^:]*: (.*) \$$/,"$1"),"Date":"$LastChangedDate: 2007-02-22 02:11:56 +0100 (Do, 22 Feb 2007) $".replace(/^[^:]*: ([0-9-]*) ([0-9:]*) ([+0-9]*) \((.*)\) \$/,"$4 $2 $3"),"Revision":"$LastChangedRevision: 757 $".replace(/^[^:]*: (.*) \$$/,"$1"),"RevisionBy":"$LastChangedBy: ray $".replace(/^[^:]*: (.*) \$$/,"$1")};
Xinha._resolveRelativeUrl=function(_1,_2){
if(_2.match(/^([^:]+\:)?\//)){
return _2;
}else{
var b=_1.split("/");
if(b[b.length-1]==""){
b.pop();
}
var p=_2.split("/");
if(p[0]=="."){
p.shift();
}
while(p[0]==".."){
b.pop();
p.shift();
}
return b.join("/")+"/"+p.join("/");
}
};
if(typeof _editor_url=="string"){
_editor_url=_editor_url.replace(/\x2f*$/,"/");
if(!_editor_url.match(/^([^:]+\:)?\//)){
var path=window.location.toString().split("/");
path.pop();
_editor_url=Xinha._resolveRelativeUrl(path.join("/"),_editor_url);
}
}else{
alert("WARNING: _editor_url is not set!  You should set this variable to the editor files path; it should preferably be an absolute path, like in '/htmlarea/', but it can be relative if you prefer.  Further we will try to load the editor files correctly but we'll probably fail.");
_editor_url="";
}
if(typeof _editor_lang=="string"){
_editor_lang=_editor_lang.toLowerCase();
}else{
_editor_lang="en";
}
if(typeof _editor_skin!=="string"){
_editor_skin="";
}
var __xinhas=[];
Xinha.agt=navigator.userAgent.toLowerCase();
Xinha.is_ie=((Xinha.agt.indexOf("msie")!=-1)&&(Xinha.agt.indexOf("opera")==-1));
Xinha.ie_version=parseFloat(Xinha.agt.substring(Xinha.agt.indexOf("msie")+5));
Xinha.is_opera=(Xinha.agt.indexOf("opera")!=-1);
Xinha.is_mac=(Xinha.agt.indexOf("mac")!=-1);
Xinha.is_mac_ie=(Xinha.is_ie&&Xinha.is_mac);
Xinha.is_win_ie=(Xinha.is_ie&&!Xinha.is_mac);
Xinha.is_gecko=(navigator.product=="Gecko");
Xinha.isRunLocally=document.URL.toLowerCase().search(/^file:/)!=-1;
if(Xinha.isRunLocally){
alert("Xinha *must* be installed on a web server. Locally opened files (those that use the \"file://\" protocol) cannot properly function. Xinha will try to initialize but may not be correctly loaded.");
}
function Xinha(_5,_6){
if(!_5){
throw ("Tried to create Xinha without textarea specified.");
}
if(Xinha.checkSupportedBrowser()){
if(typeof _6=="undefined"){
this.config=new Xinha.Config();
}else{
this.config=_6;
}
this._htmlArea=null;
if(typeof _5!="object"){
_5=Xinha.getElementById("textarea",_5);
}
this._textArea=_5;
this._textArea.spellcheck=false;
this._initial_ta_size={w:_5.style.width?_5.style.width:(_5.offsetWidth?(_5.offsetWidth+"px"):(_5.cols+"em")),h:_5.style.height?_5.style.height:(_5.offsetHeight?(_5.offsetHeight+"px"):(_5.rows+"em"))};
if(this.config.showLoading){
var _7=document.createElement("div");
_7.id="loading_"+_5.name;
_7.className="loading";
try{
_7.style.width=_5.offsetWidth+"px";
}
catch(ex){
_7.style.width=this._initial_ta_size.w;
}
_7.style.left=Xinha.findPosX(_5)+"px";
_7.style.top=(Xinha.findPosY(_5)+parseInt(this._initial_ta_size.h,10)/2)+"px";
var _8=document.createElement("div");
_8.className="loading_main";
_8.id="loading_main_"+_5.name;
_8.appendChild(document.createTextNode(Xinha._lc("Loading in progress. Please wait !")));
var _9=document.createElement("div");
_9.className="loading_sub";
_9.id="loading_sub_"+_5.name;
_9.appendChild(document.createTextNode(Xinha._lc("Constructing main object")));
_7.appendChild(_8);
_7.appendChild(_9);
document.body.appendChild(_7);
this.setLoadingMessage("Constructing object");
}
this._editMode="wysiwyg";
this.plugins={};
this._timerToolbar=null;
this._timerUndo=null;
this._undoQueue=[this.config.undoSteps];
this._undoPos=-1;
this._customUndo=true;
this._mdoc=document;
this.doctype="";
this.__htmlarea_id_num=__xinhas.length;
__xinhas[this.__htmlarea_id_num]=this;
this._notifyListeners={};
var _a={right:{on:true,container:document.createElement("td"),panels:[]},left:{on:true,container:document.createElement("td"),panels:[]},top:{on:true,container:document.createElement("td"),panels:[]},bottom:{on:true,container:document.createElement("td"),panels:[]}};
for(var i in _a){
if(!_a[i].container){
continue;
}
_a[i].div=_a[i].container;
_a[i].container.className="panels "+i;
Xinha.freeLater(_a[i],"container");
Xinha.freeLater(_a[i],"div");
}
this._panels=_a;
Xinha.freeLater(this,"_textArea");
}
}
Xinha.onload=function(){
};
Xinha.init=function(){
Xinha.onload();
};
Xinha.RE_tagName=/(<\/|<)\s*([^ \t\n>]+)/ig;
Xinha.RE_doctype=/(<!doctype((.|\n)*?)>)\n?/i;
Xinha.RE_head=/<head>((.|\n)*?)<\/head>/i;
Xinha.RE_body=/<body[^>]*>((.|\n|\r|\t)*?)<\/body>/i;
Xinha.RE_Specials=/([\/\^$*+?.()|{}[\]])/g;
Xinha.RE_email=/[_a-zA-Z\d\-\.]{3,}@[_a-zA-Z\d\-]{2,}(\.[_a-zA-Z\d\-]{2,})+/i;
Xinha.RE_url=/(https?:\/\/)?(([a-z0-9_]+:[a-z0-9_]+@)?[a-z0-9_-]{2,}(\.[a-z0-9_-]{2,}){2,}(:[0-9]+)?(\/\S+)*)/i;
Xinha.Config=function(){
var _c=this;
this.version=Xinha.version.Revision;
this.width="auto";
this.height="auto";
this.sizeIncludesBars=true;
this.sizeIncludesPanels=true;
this.panel_dimensions={left:"200px",right:"200px",top:"100px",bottom:"100px"};
this.statusBar=true;
this.htmlareaPaste=false;
this.mozParaHandler="best";
this.getHtmlMethod="DOMwalk";
this.undoSteps=20;
this.undoTimeout=500;
this.changeJustifyWithDirection=false;
this.fullPage=false;
this.pageStyle="";
this.pageStyleSheets=[];
this.baseHref=null;
this.expandRelativeUrl=true;
this.stripBaseHref=true;
this.stripSelfNamedAnchors=true;
this.only7BitPrintablesInURLs=true;
this.sevenBitClean=false;
this.specialReplacements={};
this.killWordOnPaste=true;
this.makeLinkShowsTarget=true;
this.charSet=Xinha.is_gecko?document.characterSet:document.charset;
this.imgURL="images/";
this.popupURL="popups/";
this.htmlRemoveTags=null;
this.flowToolbars=true;
this.showLoading=false;
this.stripScripts=true;
this.convertUrlsToLinks=true;
this.colorPickerCellSize="6px";
this.colorPickerGranularity=18;
this.colorPickerPosition="bottom,right";
this.colorPickerWebSafe=false;
this.colorPickerSaveColors=20;
this.fullScreen=false;
this.fullScreenMargins=[0,0,0,0];
this.toolbar=[["popupeditor"],["separator","formatblock","fontname","fontsize","bold","italic","underline","strikethrough"],["separator","forecolor","hilitecolor","textindicator"],["separator","subscript","superscript"],["linebreak","separator","justifyleft","justifycenter","justifyright","justifyfull"],["separator","insertorderedlist","insertunorderedlist","outdent","indent"],["separator","inserthorizontalrule","createlink","insertimage","inserttable"],["linebreak","separator","undo","redo","selectall","print"],(Xinha.is_gecko?[]:["cut","copy","paste","overwrite","saveas"]),["separator","killword","clearfonts","removeformat","toggleborders","splitblock","lefttoright","righttoleft"],["separator","htmlmode","showhelp","about"]];
this.fontname={"&mdash; font &mdash;":"","Arial":"arial,helvetica,sans-serif","Courier New":"courier new,courier,monospace","Georgia":"georgia,times new roman,times,serif","Tahoma":"tahoma,arial,helvetica,sans-serif","Times New Roman":"times new roman,times,serif","Verdana":"verdana,arial,helvetica,sans-serif","impact":"impact","WingDings":"wingdings"};
this.fontsize={"&mdash; size &mdash;":"","1 (8 pt)":"1","2 (10 pt)":"2","3 (12 pt)":"3","4 (14 pt)":"4","5 (18 pt)":"5","6 (24 pt)":"6","7 (36 pt)":"7"};
this.formatblock={"&mdash; format &mdash;":"","Heading 1":"h1","Heading 2":"h2","Heading 3":"h3","Heading 4":"h4","Heading 5":"h5","Heading 6":"h6","Normal":"p","Address":"address","Formatted":"pre"};
this.customSelects={};
function cut_copy_paste(e,_e,_f){
e.execCommand(_e);
}
this.debug=true;
this.URIs={"blank":"popups/blank.html","link":_editor_url+"modules/CreateLink/link.html","insert_image":_editor_url+"modules/InsertImage/insert_image.html","insert_table":_editor_url+"modules/InsertTable/insert_table.html","select_color":"select_color.html","about":"about.html","help":"editor_help.html"};
this.btnList={bold:["Bold",Xinha._lc({key:"button_bold",string:["ed_buttons_main.gif",3,2]},"Xinha"),false,function(e){
e.execCommand("bold");
}],italic:["Italic",Xinha._lc({key:"button_italic",string:["ed_buttons_main.gif",2,2]},"Xinha"),false,function(e){
e.execCommand("italic");
}],underline:["Underline",Xinha._lc({key:"button_underline",string:["ed_buttons_main.gif",2,0]},"Xinha"),false,function(e){
e.execCommand("underline");
}],strikethrough:["Strikethrough",Xinha._lc({key:"button_strikethrough",string:["ed_buttons_main.gif",3,0]},"Xinha"),false,function(e){
e.execCommand("strikethrough");
}],subscript:["Subscript",Xinha._lc({key:"button_subscript",string:["ed_buttons_main.gif",3,1]},"Xinha"),false,function(e){
e.execCommand("subscript");
}],superscript:["Superscript",Xinha._lc({key:"button_superscript",string:["ed_buttons_main.gif",2,1]},"Xinha"),false,function(e){
e.execCommand("superscript");
}],justifyleft:["Justify Left",["ed_buttons_main.gif",0,0],false,function(e){
e.execCommand("justifyleft");
}],justifycenter:["Justify Center",["ed_buttons_main.gif",1,1],false,function(e){
e.execCommand("justifycenter");
}],justifyright:["Justify Right",["ed_buttons_main.gif",1,0],false,function(e){
e.execCommand("justifyright");
}],justifyfull:["Justify Full",["ed_buttons_main.gif",0,1],false,function(e){
e.execCommand("justifyfull");
}],orderedlist:["Ordered List",["ed_buttons_main.gif",0,3],false,function(e){
e.execCommand("insertorderedlist");
}],unorderedlist:["Bulleted List",["ed_buttons_main.gif",1,3],false,function(e){
e.execCommand("insertunorderedlist");
}],insertorderedlist:["Ordered List",["ed_buttons_main.gif",0,3],false,function(e){
e.execCommand("insertorderedlist");
}],insertunorderedlist:["Bulleted List",["ed_buttons_main.gif",1,3],false,function(e){
e.execCommand("insertunorderedlist");
}],outdent:["Decrease Indent",["ed_buttons_main.gif",1,2],false,function(e){
e.execCommand("outdent");
}],indent:["Increase Indent",["ed_buttons_main.gif",0,2],false,function(e){
e.execCommand("indent");
}],forecolor:["Font Color",["ed_buttons_main.gif",3,3],false,function(e){
e.execCommand("forecolor");
}],hilitecolor:["Background Color",["ed_buttons_main.gif",2,3],false,function(e){
e.execCommand("hilitecolor");
}],undo:["Undoes your last action",["ed_buttons_main.gif",4,2],false,function(e){
e.execCommand("undo");
}],redo:["Redoes your last action",["ed_buttons_main.gif",5,2],false,function(e){
e.execCommand("redo");
}],cut:["Cut selection",["ed_buttons_main.gif",5,0],false,cut_copy_paste],copy:["Copy selection",["ed_buttons_main.gif",4,0],false,cut_copy_paste],paste:["Paste from clipboard",["ed_buttons_main.gif",4,1],false,cut_copy_paste],selectall:["Select all","ed_selectall.gif",false,function(e){
e.execCommand("selectall");
}],inserthorizontalrule:["Horizontal Rule",["ed_buttons_main.gif",6,0],false,function(e){
e.execCommand("inserthorizontalrule");
}],createlink:["Insert Web Link",["ed_buttons_main.gif",6,1],false,function(e){
e._createLink();
}],insertimage:["Insert/Modify Image",["ed_buttons_main.gif",6,3],false,function(e){
e.execCommand("insertimage");
}],inserttable:["Insert Table",["ed_buttons_main.gif",6,2],false,function(e){
e.execCommand("inserttable");
}],htmlmode:["Toggle HTML Source",["ed_buttons_main.gif",7,0],true,function(e){
e.execCommand("htmlmode");
}],toggleborders:["Toggle Borders",["ed_buttons_main.gif",7,2],false,function(e){
e._toggleBorders();
}],print:["Print document",["ed_buttons_main.gif",8,1],false,function(e){
if(Xinha.is_gecko){
e._iframe.contentWindow.print();
}else{
e.focusEditor();
print();
}
}],saveas:["Save as","ed_saveas.gif",false,function(e){
e.execCommand("saveas",false,"noname.htm");
}],about:["About this editor",["ed_buttons_main.gif",8,2],true,function(e){
e.execCommand("about");
}],showhelp:["Help using editor",["ed_buttons_main.gif",9,2],true,function(e){
e.execCommand("showhelp");
}],splitblock:["Split Block","ed_splitblock.gif",false,function(e){
e._splitBlock();
}],lefttoright:["Direction left to right",["ed_buttons_main.gif",0,4],false,function(e){
e.execCommand("lefttoright");
}],righttoleft:["Direction right to left",["ed_buttons_main.gif",1,4],false,function(e){
e.execCommand("righttoleft");
}],overwrite:["Insert/Overwrite","ed_overwrite.gif",false,function(e){
e.execCommand("overwrite");
}],wordclean:["MS Word Cleaner",["ed_buttons_main.gif",5,3],false,function(e){
e._wordClean();
}],clearfonts:["Clear Inline Font Specifications",["ed_buttons_main.gif",5,4],true,function(e){
e._clearFonts();
}],removeformat:["Remove formatting",["ed_buttons_main.gif",4,4],false,function(e){
e.execCommand("removeformat");
}],killword:["Clear MSOffice tags",["ed_buttons_main.gif",4,3],false,function(e){
e.execCommand("killword");
}]};
for(var i in this.btnList){
var btn=this.btnList[i];
if(typeof btn!="object"){
continue;
}
if(typeof btn[1]!="string"){
btn[1][0]=_editor_url+this.imgURL+btn[1][0];
}else{
btn[1]=_editor_url+this.imgURL+btn[1];
}
btn[0]=Xinha._lc(btn[0]);
}
};
Xinha.Config.prototype.registerButton=function(id,_3a,_3b,_3c,_3d,_3e){
var _3f;
if(typeof id=="string"){
_3f=id;
}else{
if(typeof id=="object"){
_3f=id.id;
}else{
alert("ERROR [Xinha.Config::registerButton]:\ninvalid arguments");
return false;
}
}
switch(typeof id){
case "string":
this.btnList[id]=[_3a,_3b,_3c,_3d,_3e];
break;
case "object":
this.btnList[id.id]=[id.tooltip,id.image,id.textMode,id.action,id.context];
break;
}
};
Xinha.prototype.registerPanel=function(_40,_41){
if(!_40){
_40="right";
}
this.setLoadingMessage("Register panel "+_40);
var _42=this.addPanel(_40);
if(_41){
_41.drawPanelIn(_42);
}
};
Xinha.Config.prototype.registerDropdown=function(_43){
this.customSelects[_43.id]=_43;
};
Xinha.Config.prototype.hideSomeButtons=function(_44){
var _45=this.toolbar;
for(var i=_45.length;--i>=0;){
var _47=_45[i];
for(var j=_47.length;--j>=0;){
if(_44.indexOf(" "+_47[j]+" ")>=0){
var len=1;
if(/separator|space/.test(_47[j+1])){
len=2;
}
_47.splice(j,len);
}
}
}
};
Xinha.Config.prototype.addToolbarElement=function(id,_4b,_4c){
var _4d=this.toolbar;
var a,i,j,o,sid;
var _4f=false;
var _50=false;
var _51=0;
var _52=0;
var _53=0;
var _54=false;
var _55=false;
if((id&&typeof id=="object")&&(id.constructor==Array)){
_4f=true;
}
if((_4b&&typeof _4b=="object")&&(_4b.constructor==Array)){
_50=true;
_51=_4b.length;
}
if(_4f){
for(i=0;i<id.length;++i){
if((id[i]!="separator")&&(id[i].indexOf("T[")!==0)){
sid=id[i];
}
}
}else{
sid=id;
}
for(i=0;i<_4d.length;++i){
a=_4d[i];
for(j=0;j<a.length;++j){
if(a[j]==sid){
return;
}
}
}
for(i=0;!_55&&i<_4d.length;++i){
a=_4d[i];
for(j=0;!_55&&j<a.length;++j){
if(_50){
for(o=0;o<_51;++o){
if(a[j]==_4b[o]){
if(o===0){
_55=true;
j--;
break;
}else{
_53=i;
_52=j;
_51=o;
}
}
}
}else{
if(a[j]==_4b){
_55=true;
break;
}
}
}
}
if(!_55&&_50){
if(_4b.length!=_51){
j=_52;
a=_4d[_53];
_55=true;
}
}
if(_55){
if(_4c===0){
if(_4f){
a[j]=id[id.length-1];
for(i=id.length-1;--i>=0;){
a.splice(j,0,id[i]);
}
}else{
a[j]=id;
}
}else{
if(_4c<0){
j=j+_4c+1;
}else{
if(_4c>0){
j=j+_4c;
}
}
if(_4f){
for(i=id.length;--i>=0;){
a.splice(j,0,id[i]);
}
}else{
a.splice(j,0,id);
}
}
}else{
_4d[0].splice(0,0,"separator");
if(_4f){
for(i=id.length;--i>=0;){
_4d[0].splice(0,0,id[i]);
}
}else{
_4d[0].splice(0,0,id);
}
}
};
Xinha.Config.prototype.removeToolbarElement=Xinha.Config.prototype.hideSomeButtons;
Xinha.replaceAll=function(_56){
var tas=document.getElementsByTagName("textarea");
for(var i=tas.length;i>0;(new Xinha(tas[--i],_56)).generate()){
}
};
Xinha.replace=function(id,_5a){
var ta=Xinha.getElementById("textarea",id);
return ta?(new Xinha(ta,_5a)).generate():null;
};
Xinha.prototype._createToolbar=function(){
this.setLoadingMessage("Create Toolbar");
var _5c=this;
var _5d=document.createElement("div");
this._toolBar=this._toolbar=_5d;
_5d.className="toolbar";
_5d.unselectable="1";
Xinha.freeLater(this,"_toolBar");
Xinha.freeLater(this,"_toolbar");
var _5e=null;
var _5f={};
this._toolbarObjects=_5f;
this._createToolbar1(_5c,_5d,_5f);
this._htmlArea.appendChild(_5d);
return _5d;
};
Xinha.prototype._setConfig=function(_60){
this.config=_60;
};
Xinha.prototype._addToolbar=function(){
this._createToolbar1(this,this._toolbar,this._toolbarObjects);
};
Xinha._createToolbarBreakingElement=function(){
var brk=document.createElement("div");
brk.style.height="1px";
brk.style.width="1px";
brk.style.lineHeight="1px";
brk.style.fontSize="1px";
brk.style.clear="both";
return brk;
};
Xinha.prototype._createToolbar1=function(_62,_63,_64){
var _65;
if(_62.config.flowToolbars){
_63.appendChild(Xinha._createToolbarBreakingElement());
}
function newLine(){
if(typeof _65!="undefined"&&_65.childNodes.length===0){
return;
}
var _66=document.createElement("table");
_66.border="0px";
_66.cellSpacing="0px";
_66.cellPadding="0px";
if(_62.config.flowToolbars){
if(Xinha.is_ie){
_66.style.styleFloat="left";
}else{
_66.style.cssFloat="left";
}
}
_63.appendChild(_66);
var _67=document.createElement("tbody");
_66.appendChild(_67);
_65=document.createElement("tr");
_67.appendChild(_65);
_66.className="toolbarRow";
}
newLine();
function setButtonStatus(id,_69){
var _6a=this[id];
var el=this.element;
if(_6a!=_69){
switch(id){
case "enabled":
if(_69){
Xinha._removeClass(el,"buttonDisabled");
el.disabled=false;
}else{
Xinha._addClass(el,"buttonDisabled");
el.disabled=true;
}
break;
case "active":
if(_69){
Xinha._addClass(el,"buttonPressed");
}else{
Xinha._removeClass(el,"buttonPressed");
}
break;
}
this[id]=_69;
}
}
function createSelect(txt){
var _6d=null;
var el=null;
var cmd=null;
var _70=_62.config.customSelects;
var _71=null;
var _72="";
switch(txt){
case "fontsize":
case "fontname":
case "formatblock":
_6d=_62.config[txt];
cmd=txt;
break;
default:
cmd=txt;
var _73=_70[cmd];
if(typeof _73!="undefined"){
_6d=_73.options;
_71=_73.context;
if(typeof _73.tooltip!="undefined"){
_72=_73.tooltip;
}
}else{
alert("ERROR [createSelect]:\nCan't find the requested dropdown definition");
}
break;
}
if(_6d){
el=document.createElement("select");
el.title=_72;
var obj={name:txt,element:el,enabled:true,text:false,cmd:cmd,state:setButtonStatus,context:_71};
Xinha.freeLater(obj);
_64[txt]=obj;
for(var i in _6d){
if(typeof (_6d[i])!="string"){
continue;
}
var op=document.createElement("option");
op.innerHTML=Xinha._lc(i);
op.value=_6d[i];
el.appendChild(op);
}
Xinha._addEvent(el,"change",function(){
_62._comboSelected(el,txt);
});
}
return el;
}
function createButton(txt){
var el,btn,obj=null;
switch(txt){
case "separator":
if(_62.config.flowToolbars){
newLine();
}
el=document.createElement("div");
el.className="separator";
break;
case "space":
el=document.createElement("div");
el.className="space";
break;
case "linebreak":
newLine();
return false;
case "textindicator":
el=document.createElement("div");
el.appendChild(document.createTextNode("A"));
el.className="indicator";
el.title=Xinha._lc("Current style");
obj={name:txt,element:el,enabled:true,active:false,text:false,cmd:"textindicator",state:setButtonStatus};
Xinha.freeLater(obj);
_64[txt]=obj;
break;
default:
btn=_62.config.btnList[txt];
}
if(!el&&btn){
el=document.createElement("a");
el.style.display="block";
el.href="javascript:void(0)";
el.style.textDecoration="none";
el.title=btn[0];
el.className="button";
el.style.direction="ltr";
obj={name:txt,element:el,enabled:true,active:false,text:btn[2],cmd:btn[3],state:setButtonStatus,context:btn[4]||null};
Xinha.freeLater(el);
Xinha.freeLater(obj);
_64[txt]=obj;
el.ondrag=function(){
return false;
};
Xinha._addEvent(el,"mouseout",function(ev){
if(obj.enabled){
Xinha._removeClass(el,"buttonActive");
if(obj.active){
Xinha._addClass(el,"buttonPressed");
}
}
});
Xinha._addEvent(el,"mousedown",function(ev){
if(obj.enabled){
Xinha._addClass(el,"buttonActive");
Xinha._removeClass(el,"buttonPressed");
Xinha._stopEvent(Xinha.is_ie?window.event:ev);
}
});
Xinha._addEvent(el,"click",function(ev){
if(obj.enabled){
Xinha._removeClass(el,"buttonActive");
if(Xinha.is_gecko){
_62.activateEditor();
}
obj.cmd(_62,obj.name,obj);
Xinha._stopEvent(Xinha.is_ie?window.event:ev);
}
});
var _7c=Xinha.makeBtnImg(btn[1]);
var img=_7c.firstChild;
el.appendChild(_7c);
obj.imgel=img;
obj.swapImage=function(_7e){
if(typeof _7e!="string"){
img.src=_7e[0];
img.style.position="relative";
img.style.top=_7e[2]?("-"+(18*(_7e[2]+1))+"px"):"-18px";
img.style.left=_7e[1]?("-"+(18*(_7e[1]+1))+"px"):"-18px";
}else{
obj.imgel.src=_7e;
img.style.top="0px";
img.style.left="0px";
}
};
}else{
if(!el){
el=createSelect(txt);
}
}
return el;
}
var _7f=true;
for(var i=0;i<this.config.toolbar.length;++i){
if(!_7f){
}else{
_7f=false;
}
if(this.config.toolbar[i]===null){
this.config.toolbar[i]=["separator"];
}
var _81=this.config.toolbar[i];
for(var j=0;j<_81.length;++j){
var _83=_81[j];
var _84;
if(/^([IT])\[(.*?)\]/.test(_83)){
var _85=RegExp.$1=="I";
var _86=RegExp.$2;
if(_85){
_86=Xinha._lc(_86);
}
_84=document.createElement("td");
_65.appendChild(_84);
_84.className="label";
_84.innerHTML=_86;
}else{
if(typeof _83!="function"){
var _87=createButton(_83);
if(_87){
_84=document.createElement("td");
_84.className="toolbarElement";
_65.appendChild(_84);
_84.appendChild(_87);
}else{
if(_87===null){
alert("FIXME: Unknown toolbar item: "+_83);
}
}
}
}
}
}
if(_62.config.flowToolbars){
_63.appendChild(Xinha._createToolbarBreakingElement());
}
return _63;
};
var use_clone_img=false;
Xinha.makeBtnImg=function(_88,doc){
if(!doc){
doc=document;
}
if(!doc._xinhaImgCache){
doc._xinhaImgCache={};
Xinha.freeLater(doc._xinhaImgCache);
}
var _8a=null;
if(Xinha.is_ie&&((!doc.compatMode)||(doc.compatMode&&doc.compatMode=="BackCompat"))){
_8a=doc.createElement("span");
}else{
_8a=doc.createElement("div");
_8a.style.position="relative";
}
_8a.style.overflow="hidden";
_8a.style.width="18px";
_8a.style.height="18px";
_8a.className="buttonImageContainer";
var img=null;
if(typeof _88=="string"){
if(doc._xinhaImgCache[_88]){
img=doc._xinhaImgCache[_88].cloneNode();
}else{
img=doc.createElement("img");
img.src=_88;
img.style.width="18px";
img.style.height="18px";
if(use_clone_img){
doc._xinhaImgCache[_88]=img.cloneNode();
}
}
}else{
if(doc._xinhaImgCache[_88[0]]){
img=doc._xinhaImgCache[_88[0]].cloneNode();
}else{
img=doc.createElement("img");
img.src=_88[0];
img.style.position="relative";
if(use_clone_img){
doc._xinhaImgCache[_88[0]]=img.cloneNode();
}
}
img.style.top=_88[2]?("-"+(18*(_88[2]+1))+"px"):"-18px";
img.style.left=_88[1]?("-"+(18*(_88[1]+1))+"px"):"-18px";
}
_8a.appendChild(img);
return _8a;
};
Xinha.prototype._createStatusBar=function(){
this.setLoadingMessage("Create StatusBar");
var _8c=document.createElement("div");
_8c.className="statusBar";
this._statusBar=_8c;
Xinha.freeLater(this,"_statusBar");
var div=document.createElement("span");
div.className="statusBarTree";
div.innerHTML=Xinha._lc("Path")+": ";
this._statusBarTree=div;
Xinha.freeLater(this,"_statusBarTree");
this._statusBar.appendChild(div);
div=document.createElement("span");
div.innerHTML=Xinha._lc("You are in TEXT MODE.  Use the [<>] button to switch back to WYSIWYG.");
div.style.display="none";
this._statusBarTextMode=div;
Xinha.freeLater(this,"_statusBarTextMode");
this._statusBar.appendChild(div);
if(!this.config.statusBar){
_8c.style.display="none";
}
return _8c;
};
Xinha.prototype.generate=function(){
var i;
var _8f=this;
if(Xinha.is_ie){
if(typeof InternetExplorer=="undefined"){
Xinha.loadPlugin("InternetExplorer",function(){
_8f.generate();
},_editor_url+"modules/InternetExplorer/InternetExplorer.js");
return false;
}
_8f._browserSpecificPlugin=_8f.registerPlugin("InternetExplorer");
}else{
if(typeof Gecko=="undefined"){
Xinha.loadPlugin("Gecko",function(){
_8f.generate();
},_editor_url+"modules/Gecko/Gecko.js");
return false;
}
_8f._browserSpecificPlugin=_8f.registerPlugin("Gecko");
}
this.setLoadingMessage("Generate Xinha object");
if(typeof Dialog=="undefined"){
Xinha._loadback(_editor_url+"modules/Dialogs/dialog.js",this.generate,this);
return false;
}
if(typeof Xinha.Dialog=="undefined"){
Xinha._loadback(_editor_url+"modules/Dialogs/inline-dialog.js",this.generate,this);
return false;
}
if(typeof FullScreen=="undefined"){
Xinha.loadPlugin("FullScreen",function(){
_8f.generate();
},_editor_url+"modules/FullScreen/full-screen.js");
return false;
}
var _90=_8f.config.toolbar;
for(i=_90.length;--i>=0;){
for(var j=_90[i].length;--j>=0;){
switch(_90[i][j]){
case "popupeditor":
_8f.registerPlugin("FullScreen");
break;
case "insertimage":
if(typeof InsertImage=="undefined"&&typeof Xinha.prototype._insertImage=="undefined"){
Xinha.loadPlugin("InsertImage",function(){
_8f.generate();
},_editor_url+"modules/InsertImage/insert_image.js");
return false;
}else{
if(typeof InsertImage!="undefined"){
_8f.registerPlugin("InsertImage");
}
}
break;
case "createlink":
if(typeof CreateLink=="undefined"&&typeof Xinha.prototype._createLink=="undefined"&&typeof Linker=="undefined"){
Xinha.loadPlugin("CreateLink",function(){
_8f.generate();
},_editor_url+"modules/CreateLink/link.js");
return false;
}else{
if(typeof CreateLink!="undefined"){
_8f.registerPlugin("CreateLink");
}
}
break;
case "inserttable":
if(typeof InsertTable=="undefined"&&typeof Xinha.prototype._insertTable=="undefined"){
Xinha.loadPlugin("InsertTable",function(){
_8f.generate();
},_editor_url+"modules/InsertTable/insert_table.js");
return false;
}else{
if(typeof InsertTable!="undefined"){
_8f.registerPlugin("InsertTable");
}
}
break;
case "hilitecolor":
case "forecolor":
if(typeof ColorPicker=="undefined"){
Xinha.loadPlugin("ColorPicker",function(){
_8f.generate();
},_editor_url+"modules/ColorPicker/ColorPicker.js");
return false;
}else{
if(typeof ColorPicker!="undefined"){
_8f.registerPlugin("ColorPicker");
}
}
break;
}
}
}
if(Xinha.is_gecko&&(_8f.config.mozParaHandler=="best"||_8f.config.mozParaHandler=="dirty")){
switch(this.config.mozParaHandler){
case "dirty":
var _92=_editor_url+"modules/Gecko/paraHandlerDirty.js";
break;
default:
var _92=_editor_url+"modules/Gecko/paraHandlerBest.js";
break;
}
if(typeof EnterParagraphs=="undefined"){
Xinha.loadPlugin("EnterParagraphs",function(){
_8f.generate();
},_92);
return false;
}
_8f.registerPlugin("EnterParagraphs");
}
switch(this.config.getHtmlMethod){
case "TransformInnerHTML":
var _93=_editor_url+"modules/GetHtml/TransformInnerHTML.js";
break;
default:
var _93=_editor_url+"modules/GetHtml/DOMwalk.js";
break;
}
if(typeof GetHtmlImplementation=="undefined"){
Xinha.loadPlugin("GetHtmlImplementation",function(){
_8f.generate();
},_93);
return false;
}else{
_8f.registerPlugin("GetHtmlImplementation");
}
if(_editor_skin!==""){
var _94=false;
var _95=document.getElementsByTagName("head")[0];
var _96=document.getElementsByTagName("link");
for(i=0;i<_96.length;i++){
if((_96[i].rel=="stylesheet")&&(_96[i].href==_editor_url+"skins/"+_editor_skin+"/skin.css")){
_94=true;
}
}
if(!_94){
var _97=document.createElement("link");
_97.type="text/css";
_97.href=_editor_url+"skins/"+_editor_skin+"/skin.css";
_97.rel="stylesheet";
_95.appendChild(_97);
}
}
this._framework={"table":document.createElement("table"),"tbody":document.createElement("tbody"),"tb_row":document.createElement("tr"),"tb_cell":document.createElement("td"),"tp_row":document.createElement("tr"),"tp_cell":this._panels.top.container,"ler_row":document.createElement("tr"),"lp_cell":this._panels.left.container,"ed_cell":document.createElement("td"),"rp_cell":this._panels.right.container,"bp_row":document.createElement("tr"),"bp_cell":this._panels.bottom.container,"sb_row":document.createElement("tr"),"sb_cell":document.createElement("td")};
Xinha.freeLater(this._framework);
var fw=this._framework;
fw.table.border="0";
fw.table.cellPadding="0";
fw.table.cellSpacing="0";
fw.tb_row.style.verticalAlign="top";
fw.tp_row.style.verticalAlign="top";
fw.ler_row.style.verticalAlign="top";
fw.bp_row.style.verticalAlign="top";
fw.sb_row.style.verticalAlign="top";
fw.ed_cell.style.position="relative";
fw.tb_row.appendChild(fw.tb_cell);
fw.tb_cell.colSpan=3;
fw.tp_row.appendChild(fw.tp_cell);
fw.tp_cell.colSpan=3;
fw.ler_row.appendChild(fw.lp_cell);
fw.ler_row.appendChild(fw.ed_cell);
fw.ler_row.appendChild(fw.rp_cell);
fw.bp_row.appendChild(fw.bp_cell);
fw.bp_cell.colSpan=3;
fw.sb_row.appendChild(fw.sb_cell);
fw.sb_cell.colSpan=3;
fw.tbody.appendChild(fw.tb_row);
fw.tbody.appendChild(fw.tp_row);
fw.tbody.appendChild(fw.ler_row);
fw.tbody.appendChild(fw.bp_row);
fw.tbody.appendChild(fw.sb_row);
fw.table.appendChild(fw.tbody);
var _99=this._framework.table;
this._htmlArea=_99;
Xinha.freeLater(this,"_htmlArea");
_99.className="htmlarea";
this._framework.tb_cell.appendChild(this._createToolbar());
var _9a=document.createElement("iframe");
_9a.src=_editor_url+_8f.config.URIs.blank;
this._framework.ed_cell.appendChild(_9a);
this._iframe=_9a;
this._iframe.className="xinha_iframe";
Xinha.freeLater(this,"_iframe");
var _9b=this._createStatusBar();
this._framework.sb_cell.appendChild(_9b);
var _9c=this._textArea;
_9c.parentNode.insertBefore(_99,_9c);
_9c.className="xinha_textarea";
Xinha.removeFromParent(_9c);
this._framework.ed_cell.appendChild(_9c);
if(_9c.form){
Xinha.prependDom0Event(this._textArea.form,"submit",function(){
_8f._textArea.value=_8f.outwardHtml(_8f.getHTML());
return true;
});
var _9d=_9c.value;
Xinha.prependDom0Event(this._textArea.form,"reset",function(){
_8f.setHTML(_8f.inwardHtml(_9d));
_8f.updateToolbar();
return true;
});
if(!_9c.form.xinha_submit){
try{
_9c.form.xinha_submit=_9c.form.submit;
_9c.form.submit=function(){
this.onsubmit();
this.xinha_submit();
};
}
catch(ex){
}
}
}
Xinha.prependDom0Event(window,"unload",function(){
_9c.value=_8f.outwardHtml(_8f.getHTML());
return true;
});
_9c.style.display="none";
_8f.initSize();
_8f._iframeLoadDone=false;
Xinha._addEvent(this._iframe,"load",function(e){
if(!_8f._iframeLoadDone){
_8f._iframeLoadDone=true;
_8f.initIframe();
}
return true;
});
};
Xinha.prototype.initSize=function(){
this.setLoadingMessage("Init editor size");
var _9f=this;
var _a0=null;
var _a1=null;
switch(this.config.width){
case "auto":
_a0=this._initial_ta_size.w;
break;
case "toolbar":
_a0=this._toolBar.offsetWidth+"px";
break;
default:
_a0=/[^0-9]/.test(this.config.width)?this.config.width:this.config.width+"px";
break;
}
switch(this.config.height){
case "auto":
_a1=this._initial_ta_size.h;
break;
default:
_a1=/[^0-9]/.test(this.config.height)?this.config.height:this.config.height+"px";
break;
}
this.sizeEditor(_a0,_a1,this.config.sizeIncludesBars,this.config.sizeIncludesPanels);
this.notifyOn("panel_change",function(){
_9f.sizeEditor();
});
};
Xinha.prototype.sizeEditor=function(_a2,_a3,_a4,_a5){
this._iframe.style.height="100%";
this._textArea.style.height="100%";
this._iframe.style.width="";
this._textArea.style.width="";
if(_a4!==null){
this._htmlArea.sizeIncludesToolbars=_a4;
}
if(_a5!==null){
this._htmlArea.sizeIncludesPanels=_a5;
}
if(_a2){
this._htmlArea.style.width=_a2;
if(!this._htmlArea.sizeIncludesPanels){
var _a6=this._panels.right;
if(_a6.on&&_a6.panels.length&&Xinha.hasDisplayedChildren(_a6.div)){
this._htmlArea.style.width=(this._htmlArea.offsetWidth+parseInt(this.config.panel_dimensions.right,10))+"px";
}
var _a7=this._panels.left;
if(_a7.on&&_a7.panels.length&&Xinha.hasDisplayedChildren(_a7.div)){
this._htmlArea.style.width=(this._htmlArea.offsetWidth+parseInt(this.config.panel_dimensions.left,10))+"px";
}
}
}
if(_a3){
this._htmlArea.style.height=_a3;
if(!this._htmlArea.sizeIncludesToolbars){
this._htmlArea.style.height=(this._htmlArea.offsetHeight+this._toolbar.offsetHeight+this._statusBar.offsetHeight)+"px";
}
if(!this._htmlArea.sizeIncludesPanels){
var _a8=this._panels.top;
if(_a8.on&&_a8.panels.length&&Xinha.hasDisplayedChildren(_a8.div)){
this._htmlArea.style.height=(this._htmlArea.offsetHeight+parseInt(this.config.panel_dimensions.top,10))+"px";
}
var _a9=this._panels.bottom;
if(_a9.on&&_a9.panels.length&&Xinha.hasDisplayedChildren(_a9.div)){
this._htmlArea.style.height=(this._htmlArea.offsetHeight+parseInt(this.config.panel_dimensions.bottom,10))+"px";
}
}
}
_a2=this._htmlArea.offsetWidth;
_a3=this._htmlArea.offsetHeight;
var _aa=this._panels;
var _ab=this;
var _ac=1;
function panel_is_alive(pan){
if(_aa[pan].on&&_aa[pan].panels.length&&Xinha.hasDisplayedChildren(_aa[pan].container)){
_aa[pan].container.style.display="";
return true;
}else{
_aa[pan].container.style.display="none";
return false;
}
}
if(panel_is_alive("left")){
_ac+=1;
}
if(panel_is_alive("right")){
_ac+=1;
}
this._framework.tb_cell.colSpan=_ac;
this._framework.tp_cell.colSpan=_ac;
this._framework.bp_cell.colSpan=_ac;
this._framework.sb_cell.colSpan=_ac;
if(!this._framework.tp_row.childNodes.length){
Xinha.removeFromParent(this._framework.tp_row);
}else{
if(!Xinha.hasParentNode(this._framework.tp_row)){
this._framework.tbody.insertBefore(this._framework.tp_row,this._framework.ler_row);
}
}
if(!this._framework.bp_row.childNodes.length){
Xinha.removeFromParent(this._framework.bp_row);
}else{
if(!Xinha.hasParentNode(this._framework.bp_row)){
this._framework.tbody.insertBefore(this._framework.bp_row,this._framework.ler_row.nextSibling);
}
}
if(!this.config.statusBar){
Xinha.removeFromParent(this._framework.sb_row);
}else{
if(!Xinha.hasParentNode(this._framework.sb_row)){
this._framework.table.appendChild(this._framework.sb_row);
}
}
this._framework.lp_cell.style.width=this.config.panel_dimensions.left;
this._framework.rp_cell.style.width=this.config.panel_dimensions.right;
this._framework.tp_cell.style.height=this.config.panel_dimensions.top;
this._framework.bp_cell.style.height=this.config.panel_dimensions.bottom;
this._framework.tb_cell.style.height=this._toolBar.offsetHeight+"px";
this._framework.sb_cell.style.height=this._statusBar.offsetHeight+"px";
var _ae=_a3-this._toolBar.offsetHeight-this._statusBar.offsetHeight;
if(panel_is_alive("top")){
_ae-=parseInt(this.config.panel_dimensions.top,10);
}
if(panel_is_alive("bottom")){
_ae-=parseInt(this.config.panel_dimensions.bottom,10);
}
this._iframe.style.height=_ae+"px";
var _af=_a2;
if(panel_is_alive("left")){
_af-=parseInt(this.config.panel_dimensions.left,10);
}
if(panel_is_alive("right")){
_af-=parseInt(this.config.panel_dimensions.right,10);
}
this._iframe.style.width=_af+"px";
this._textArea.style.height=this._iframe.style.height;
this._textArea.style.width=this._iframe.style.width;
this.notifyOf("resize",{width:this._htmlArea.offsetWidth,height:this._htmlArea.offsetHeight});
};
Xinha.prototype.addPanel=function(_b0){
var div=document.createElement("div");
div.side=_b0;
if(_b0=="left"||_b0=="right"){
div.style.width=this.config.panel_dimensions[_b0];
if(this._iframe){
div.style.height=this._iframe.style.height;
}
}
Xinha.addClasses(div,"panel");
this._panels[_b0].panels.push(div);
this._panels[_b0].div.appendChild(div);
this.notifyOf("panel_change",{"action":"add","panel":div});
return div;
};
Xinha.prototype.removePanel=function(_b2){
this._panels[_b2.side].div.removeChild(_b2);
var _b3=[];
for(var i=0;i<this._panels[_b2.side].panels.length;i++){
if(this._panels[_b2.side].panels[i]!=_b2){
_b3.push(this._panels[_b2.side].panels[i]);
}
}
this._panels[_b2.side].panels=_b3;
this.notifyOf("panel_change",{"action":"remove","panel":_b2});
};
Xinha.prototype.hidePanel=function(_b5){
if(_b5&&_b5.style.display!="none"){
try{
var pos=this.scrollPos(this._iframe.contentWindow);
}
catch(e){
}
_b5.style.display="none";
this.notifyOf("panel_change",{"action":"hide","panel":_b5});
try{
this._iframe.contentWindow.scrollTo(pos.x,pos.y);
}
catch(e){
}
}
};
Xinha.prototype.showPanel=function(_b7){
if(_b7&&_b7.style.display=="none"){
try{
var pos=this.scrollPos(this._iframe.contentWindow);
}
catch(e){
}
_b7.style.display="";
this.notifyOf("panel_change",{"action":"show","panel":_b7});
try{
this._iframe.contentWindow.scrollTo(pos.x,pos.y);
}
catch(e){
}
}
};
Xinha.prototype.hidePanels=function(_b9){
if(typeof _b9=="undefined"){
_b9=["left","right","top","bottom"];
}
var _ba=[];
for(var i=0;i<_b9.length;i++){
if(this._panels[_b9[i]].on){
_ba.push(_b9[i]);
this._panels[_b9[i]].on=false;
}
}
this.notifyOf("panel_change",{"action":"multi_hide","sides":_b9});
};
Xinha.prototype.showPanels=function(_bc){
if(typeof _bc=="undefined"){
_bc=["left","right","top","bottom"];
}
var _bd=[];
for(var i=0;i<_bc.length;i++){
if(!this._panels[_bc[i]].on){
_bd.push(_bc[i]);
this._panels[_bc[i]].on=true;
}
}
this.notifyOf("panel_change",{"action":"multi_show","sides":_bc});
};
Xinha.objectProperties=function(obj){
var _c0=[];
for(var x in obj){
_c0[_c0.length]=x;
}
return _c0;
};
Xinha.prototype.editorIsActivated=function(){
try{
return Xinha.is_gecko?this._doc.designMode=="on":this._doc.body.contentEditable;
}
catch(ex){
return false;
}
};
Xinha._someEditorHasBeenActivated=false;
Xinha._currentlyActiveEditor=false;
Xinha.prototype.activateEditor=function(){
if(Xinha._currentlyActiveEditor){
if(Xinha._currentlyActiveEditor==this){
return true;
}
Xinha._currentlyActiveEditor.deactivateEditor();
}
if(Xinha.is_gecko&&this._doc.designMode!="on"){
try{
if(this._iframe.style.display=="none"){
this._iframe.style.display="";
this._doc.designMode="on";
this._iframe.style.display="none";
}else{
this._doc.designMode="on";
}
}
catch(ex){
}
}else{
if(!Xinha.is_gecko&&this._doc.body.contentEditable!==true){
this._doc.body.contentEditable=true;
}
}
Xinha._someEditorHasBeenActivated=true;
Xinha._currentlyActiveEditor=this;
var _c2=this;
this.enableToolbar();
};
Xinha.prototype.deactivateEditor=function(){
this.disableToolbar();
if(Xinha.is_gecko&&this._doc.designMode!="off"){
try{
this._doc.designMode="off";
}
catch(ex){
}
}else{
if(!Xinha.is_gecko&&this._doc.body.contentEditable!==false){
this._doc.body.contentEditable=false;
}
}
if(Xinha._currentlyActiveEditor!=this){
return;
}
Xinha._currentlyActiveEditor=false;
};
Xinha.prototype.initIframe=function(){
this.setLoadingMessage("Init IFrame");
this.disableToolbar();
var doc=null;
var _c4=this;
try{
if(_c4._iframe.contentDocument){
this._doc=_c4._iframe.contentDocument;
}else{
this._doc=_c4._iframe.contentWindow.document;
}
doc=this._doc;
if(!doc){
if(Xinha.is_gecko){
setTimeout(function(){
_c4.initIframe();
},50);
return false;
}else{
alert("ERROR: IFRAME can't be initialized.");
}
}
}
catch(ex){
setTimeout(function(){
_c4.initIframe();
},50);
}
Xinha.freeLater(this,"_doc");
doc.open("text/html","replace");
var _c5="";
if(!_c4.config.fullPage){
_c5="<html>\n";
_c5+="<head>\n";
_c5+="<meta http-equiv=\"Content-Type\" content=\"text/html; charset="+_c4.config.charSet+"\">\n";
if(typeof _c4.config.baseHref!="undefined"&&_c4.config.baseHref!==null){
_c5+="<base href=\""+_c4.config.baseHref+"\"/>\n";
}
_c5+=Xinha.addCoreCSS();
if(_c4.config.pageStyle){
_c5+="<style type=\"text/css\">\n"+_c4.config.pageStyle+"\n</style>";
}
if(typeof _c4.config.pageStyleSheets!=="undefined"){
for(var i=0;i<_c4.config.pageStyleSheets.length;i++){
if(_c4.config.pageStyleSheets[i].length>0){
_c5+="<link rel=\"stylesheet\" type=\"text/css\" href=\""+_c4.config.pageStyleSheets[i]+"\">";
}
}
}
_c5+="</head>\n";
_c5+="<body>\n";
_c5+=_c4.inwardHtml(_c4._textArea.value);
_c5+="</body>\n";
_c5+="</html>";
}else{
_c5=_c4.inwardHtml(_c4._textArea.value);
if(_c5.match(Xinha.RE_doctype)){
_c4.setDoctype(RegExp.$1);
_c5=_c5.replace(Xinha.RE_doctype,"");
}
var _c7=_c5.match(/<link\s+[\s\S]*?["']\s*\/?>/gi);
_c5=_c5.replace(/<link\s+[\s\S]*?["']\s*\/?>\s*/gi,"");
_c7?_c5=_c5.replace(/<\/head>/i,_c7.join("\n")+"\n</head>"):null;
}
doc.write(_c5);
doc.close();
if(this.config.fullScreen){
this._fullScreen();
}
this.setEditorEvents();
};
Xinha.prototype.whenDocReady=function(F){
var E=this;
if(this._doc&&this._doc.body){
F();
}else{
setTimeout(function(){
E.whenDocReady(F);
},50);
}
};
Xinha.prototype.setMode=function(_ca){
var _cb;
if(typeof _ca=="undefined"){
_ca=this._editMode=="textmode"?"wysiwyg":"textmode";
}
switch(_ca){
case "textmode":
this.setCC("iframe");
_cb=this.outwardHtml(this.getHTML());
this.setHTML(_cb);
this.deactivateEditor();
this._iframe.style.display="none";
this._textArea.style.display="";
if(this.config.statusBar){
this._statusBarTree.style.display="none";
this._statusBarTextMode.style.display="";
}
this.notifyOf("modechange",{"mode":"text"});
this.findCC("textarea");
break;
case "wysiwyg":
this.setCC("textarea");
_cb=this.inwardHtml(this.getHTML());
this.deactivateEditor();
this.setHTML(_cb);
this._iframe.style.display="";
this._textArea.style.display="none";
this.activateEditor();
if(this.config.statusBar){
this._statusBarTree.style.display="";
this._statusBarTextMode.style.display="none";
}
this.notifyOf("modechange",{"mode":"wysiwyg"});
this.findCC("iframe");
break;
default:
alert("Mode <"+_ca+"> not defined!");
return false;
}
this._editMode=_ca;
for(var i in this.plugins){
var _cd=this.plugins[i].instance;
if(_cd&&typeof _cd.onMode=="function"){
_cd.onMode(_ca);
}
}
};
Xinha.prototype.setFullHTML=function(_ce){
var _cf=RegExp.multiline;
RegExp.multiline=true;
if(_ce.match(Xinha.RE_doctype)){
this.setDoctype(RegExp.$1);
_ce=_ce.replace(Xinha.RE_doctype,"");
}
RegExp.multiline=_cf;
if(0){
if(_ce.match(Xinha.RE_head)){
this._doc.getElementsByTagName("head")[0].innerHTML=RegExp.$1;
}
if(_ce.match(Xinha.RE_body)){
this._doc.getElementsByTagName("body")[0].innerHTML=RegExp.$1;
}
}else{
var _d0=this.editorIsActivated();
if(_d0){
this.deactivateEditor();
}
var _d1=/<html>((.|\n)*?)<\/html>/i;
_ce=_ce.replace(_d1,"$1");
this._doc.open("text/html","replace");
this._doc.write(_ce);
this._doc.close();
if(_d0){
this.activateEditor();
}
this.setEditorEvents();
return true;
}
};
Xinha.prototype.setEditorEvents=function(){
var _d2=this;
var doc=this._doc;
_d2.whenDocReady(function(){
Xinha._addEvents(doc,["mousedown"],function(){
_d2.activateEditor();
return true;
});
Xinha._addEvents(doc,["keydown","keypress","mousedown","mouseup","drag"],function(_d4){
return _d2._editorEvent(Xinha.is_ie?_d2._iframe.contentWindow.event:_d4);
});
for(var i in _d2.plugins){
var _d6=_d2.plugins[i].instance;
Xinha.refreshPlugin(_d6);
}
if(typeof _d2._onGenerate=="function"){
_d2._onGenerate();
}
Xinha.addDom0Event(window,"resize",function(e){
_d2.sizeEditor();
});
_d2.removeLoadingMessage();
});
};
Xinha.prototype.registerPlugin=function(){
var _d8=arguments[0];
if(_d8===null||typeof _d8=="undefined"||(typeof _d8=="string"&&eval("typeof "+_d8)=="undefined")){
return false;
}
var _d9=[];
for(var i=1;i<arguments.length;++i){
_d9.push(arguments[i]);
}
return this.registerPlugin2(_d8,_d9);
};
Xinha.prototype.registerPlugin2=function(_db,_dc){
if(typeof _db=="string"){
_db=eval(_db);
}
if(typeof _db=="undefined"){
return false;
}
var obj=new _db(this,_dc);
if(obj){
var _de={};
var _df=_db._pluginInfo;
for(var i in _df){
_de[i]=_df[i];
}
_de.instance=obj;
_de.args=_dc;
this.plugins[_db._pluginInfo.name]=_de;
return obj;
}else{
alert("Can't register plugin "+_db.toString()+".");
}
};
Xinha.getPluginDir=function(_e1){
return _editor_url+"plugins/"+_e1;
};
Xinha.loadPlugin=function(_e2,_e3,_e4){
if(eval("typeof "+_e2)!="undefined"){
if(_e3){
_e3(_e2);
}
return true;
}
if(!_e4){
var dir=this.getPluginDir(_e2);
var _e6=_e2.replace(/([a-z])([A-Z])([a-z])/g,function(str,l1,l2,l3){
return l1+"-"+l2.toLowerCase()+l3;
}).toLowerCase()+".js";
_e4=dir+"/"+_e6;
}
Xinha._loadback(_e4,_e3?function(){
_e3(_e2);
}:null);
return false;
};
Xinha._pluginLoadStatus={};
Xinha.loadPlugins=function(_eb,_ec){
var _ed=true;
var _ee=Xinha.cloneObject(_eb);
while(_ee.length){
var p=_ee.pop();
if(typeof Xinha._pluginLoadStatus[p]=="undefined"){
Xinha._pluginLoadStatus[p]="loading";
Xinha.loadPlugin(p,function(_f0){
if(eval("typeof "+_f0)!="undefined"){
Xinha._pluginLoadStatus[_f0]="ready";
}else{
Xinha._pluginLoadStatus[_f0]="failed";
}
});
_ed=false;
}else{
switch(Xinha._pluginLoadStatus[p]){
case "failed":
case "ready":
break;
default:
_ed=false;
break;
}
}
}
if(_ed){
return true;
}
if(_ec){
setTimeout(function(){
if(Xinha.loadPlugins(_eb,_ec)){
_ec();
}
},150);
}
return _ed;
};
Xinha.refreshPlugin=function(_f1){
if(_f1&&typeof _f1.onGenerate=="function"){
_f1.onGenerate();
}
if(_f1&&typeof _f1.onGenerateOnce=="function"){
_f1.onGenerateOnce();
_f1.onGenerateOnce=null;
}
};
Xinha.prototype.firePluginEvent=function(_f2){
var _f3=[];
for(var i=1;i<arguments.length;i++){
_f3[i-1]=arguments[i];
}
for(var i in this.plugins){
var _f5=this.plugins[i].instance;
if(_f5==this._browserSpecificPlugin){
continue;
}
if(_f5&&typeof _f5[_f2]=="function"){
if(_f5[_f2].apply(_f5,_f3)){
return true;
}
}
}
var _f5=this._browserSpecificPlugin;
if(_f5&&typeof _f5[_f2]=="function"){
if(_f5[_f2].apply(_f5,_f3)){
return true;
}
}
return false;
};
Xinha.loadStyle=function(_f6,_f7){
var url=_editor_url||"";
if(typeof _f7!="undefined"){
url+="plugins/"+_f7+"/";
}
url+=_f6;
if(/^\//.test(_f6)){
url=_f6;
}
var _f9=document.getElementsByTagName("head")[0];
var _fa=document.createElement("link");
_fa.rel="stylesheet";
_fa.href=url;
_f9.appendChild(_fa);
};
Xinha.loadStyle(typeof _editor_css=="string"?_editor_css:"Xinha.css");
Xinha.prototype.debugTree=function(){
var ta=document.createElement("textarea");
ta.style.width="100%";
ta.style.height="20em";
ta.value="";
function debug(_fc,str){
for(;--_fc>=0;){
ta.value+=" ";
}
ta.value+=str+"\n";
}
function _dt(_fe,_ff){
var tag=_fe.tagName.toLowerCase(),i;
var ns=Xinha.is_ie?_fe.scopeName:_fe.prefix;
debug(_ff,"- "+tag+" ["+ns+"]");
for(i=_fe.firstChild;i;i=i.nextSibling){
if(i.nodeType==1){
_dt(i,_ff+2);
}
}
}
_dt(this._doc.body,0);
document.body.appendChild(ta);
};
Xinha.getInnerText=function(el){
var txt="",i;
for(i=el.firstChild;i;i=i.nextSibling){
if(i.nodeType==3){
txt+=i.data;
}else{
if(i.nodeType==1){
txt+=Xinha.getInnerText(i);
}
}
}
return txt;
};
Xinha.prototype._wordClean=function(){
var _104=this;
var _105={empty_tags:0,mso_class:0,mso_style:0,mso_xmlel:0,orig_len:this._doc.body.innerHTML.length,T:(new Date()).getTime()};
var _106={empty_tags:"Empty tags removed: ",mso_class:"MSO class names removed: ",mso_style:"MSO inline style removed: ",mso_xmlel:"MSO XML elements stripped: "};
function showStats(){
var txt="Xinha word cleaner stats: \n\n";
for(var i in _105){
if(_106[i]){
txt+=_106[i]+_105[i]+"\n";
}
}
txt+="\nInitial document length: "+_105.orig_len+"\n";
txt+="Final document length: "+_104._doc.body.innerHTML.length+"\n";
txt+="Clean-up took "+(((new Date()).getTime()-_105.T)/1000)+" seconds";
alert(txt);
}
function clearClass(node){
var newc=node.className.replace(/(^|\s)mso.*?(\s|$)/ig," ");
if(newc!=node.className){
node.className=newc;
if(!(/\S/.test(node.className))){
node.removeAttribute("className");
++_105.mso_class;
}
}
}
function clearStyle(node){
var _10c=node.style.cssText.split(/\s*;\s*/);
for(var i=_10c.length;--i>=0;){
if((/^mso|^tab-stops/i.test(_10c[i]))||(/^margin\s*:\s*0..\s+0..\s+0../i.test(_10c[i]))){
++_105.mso_style;
_10c.splice(i,1);
}
}
node.style.cssText=_10c.join("; ");
}
var _10e=null;
if(Xinha.is_ie){
_10e=function(el){
el.outerHTML=Xinha.htmlEncode(el.innerText);
++_105.mso_xmlel;
};
}else{
_10e=function(el){
var txt=document.createTextNode(Xinha.getInnerText(el));
el.parentNode.insertBefore(txt,el);
Xinha.removeFromParent(el);
++_105.mso_xmlel;
};
}
function checkEmpty(el){
if(/^(span|b|strong|i|em|font|div|p)$/i.test(el.tagName)&&!el.firstChild){
Xinha.removeFromParent(el);
++_105.empty_tags;
}
}
function parseTree(root){
var tag=root.tagName.toLowerCase(),i,next;
if((Xinha.is_ie&&root.scopeName!="HTML")||(!Xinha.is_ie&&(/:/.test(tag)))){
_10e(root);
return false;
}else{
clearClass(root);
clearStyle(root);
for(i=root.firstChild;i;i=next){
next=i.nextSibling;
if(i.nodeType==1&&parseTree(i)){
checkEmpty(i);
}
}
}
return true;
}
parseTree(this._doc.body);
this.updateToolbar();
};
Xinha.prototype._clearFonts=function(){
var D=this.getInnerHTML();
if(confirm(Xinha._lc("Would you like to clear font typefaces?"))){
D=D.replace(/face="[^"]*"/gi,"");
D=D.replace(/font-family:[^;}"']+;?/gi,"");
}
if(confirm(Xinha._lc("Would you like to clear font sizes?"))){
D=D.replace(/size="[^"]*"/gi,"");
D=D.replace(/font-size:[^;}"']+;?/gi,"");
}
if(confirm(Xinha._lc("Would you like to clear font colours?"))){
D=D.replace(/color="[^"]*"/gi,"");
D=D.replace(/([^-])color:[^;}"']+;?/gi,"$1");
}
D=D.replace(/(style|class)="\s*"/gi,"");
D=D.replace(/<(font|span)\s*>/gi,"");
this.setHTML(D);
this.updateToolbar();
};
Xinha.prototype._splitBlock=function(){
this._doc.execCommand("formatblock",false,"div");
};
Xinha.prototype.forceRedraw=function(){
this._doc.body.style.visibility="hidden";
this._doc.body.style.visibility="";
};
Xinha.prototype.focusEditor=function(){
switch(this._editMode){
case "wysiwyg":
try{
if(Xinha._someEditorHasBeenActivated){
this.activateEditor();
this._iframe.contentWindow.focus();
}
}
catch(ex){
}
break;
case "textmode":
try{
this._textArea.focus();
}
catch(e){
}
break;
default:
alert("ERROR: mode "+this._editMode+" is not defined");
}
return this._doc;
};
Xinha.prototype._undoTakeSnapshot=function(){
++this._undoPos;
if(this._undoPos>=this.config.undoSteps){
this._undoQueue.shift();
--this._undoPos;
}
var take=true;
var txt=this.getInnerHTML();
if(this._undoPos>0){
take=(this._undoQueue[this._undoPos-1]!=txt);
}
if(take){
this._undoQueue[this._undoPos]=txt;
}else{
this._undoPos--;
}
};
Xinha.prototype.undo=function(){
if(this._undoPos>0){
var txt=this._undoQueue[--this._undoPos];
if(txt){
this.setHTML(txt);
}else{
++this._undoPos;
}
}
};
Xinha.prototype.redo=function(){
if(this._undoPos<this._undoQueue.length-1){
var txt=this._undoQueue[++this._undoPos];
if(txt){
this.setHTML(txt);
}else{
--this._undoPos;
}
}
};
Xinha.prototype.disableToolbar=function(_11a){
if(this._timerToolbar){
clearTimeout(this._timerToolbar);
}
if(typeof _11a=="undefined"){
_11a=[];
}else{
if(typeof _11a!="object"){
_11a=[_11a];
}
}
for(var i in this._toolbarObjects){
var btn=this._toolbarObjects[i];
if(_11a.contains(i)){
continue;
}
if(typeof (btn.state)!="function"){
continue;
}
btn.state("enabled",false);
}
};
Xinha.prototype.enableToolbar=function(){
this.updateToolbar();
};
if(!Array.prototype.contains){
Array.prototype.contains=function(_11d){
var _11e=this;
for(var i=0;i<_11e.length;i++){
if(_11d==_11e[i]){
return true;
}
}
return false;
};
}
if(!Array.prototype.indexOf){
Array.prototype.indexOf=function(_120){
var _121=this;
for(var i=0;i<_121.length;i++){
if(_120==_121[i]){
return i;
}
}
return null;
};
}
Xinha.prototype.updateToolbar=function(_123){
var doc=this._doc;
var text=(this._editMode=="textmode");
var _126=null;
if(!text){
_126=this.getAllAncestors();
if(this.config.statusBar&&!_123){
this._statusBarTree.innerHTML=Xinha._lc("Path")+": ";
for(var i=_126.length;--i>=0;){
var el=_126[i];
if(!el){
continue;
}
var a=document.createElement("a");
a.href="javascript:void(0)";
a.el=el;
a.editor=this;
Xinha.addDom0Event(a,"click",function(){
this.blur();
this.editor.selectNodeContents(this.el);
this.editor.updateToolbar(true);
return false;
});
Xinha.addDom0Event(a,"contextmenu",function(){
this.blur();
var info="Inline style:\n\n";
info+=this.el.style.cssText.split(/;\s*/).join(";\n");
alert(info);
return false;
});
var txt=el.tagName.toLowerCase();
if(typeof el.style!="undefined"){
a.title=el.style.cssText;
}
if(el.id){
txt+="#"+el.id;
}
if(el.className){
txt+="."+el.className;
}
a.appendChild(document.createTextNode(txt));
this._statusBarTree.appendChild(a);
if(i!==0){
this._statusBarTree.appendChild(document.createTextNode(String.fromCharCode(187)));
}
}
}
}
for(var cmd in this._toolbarObjects){
var btn=this._toolbarObjects[cmd];
var _12e=true;
if(typeof (btn.state)!="function"){
continue;
}
if(btn.context&&!text){
_12e=false;
var _12f=btn.context;
var _130=[];
if(/(.*)\[(.*?)\]/.test(_12f)){
_12f=RegExp.$1;
_130=RegExp.$2.split(",");
}
_12f=_12f.toLowerCase();
var _131=(_12f=="*");
for(var k=0;k<_126.length;++k){
if(!_126[k]){
continue;
}
if(_131||(_126[k].tagName.toLowerCase()==_12f)){
_12e=true;
var _133=null;
var att=null;
var comp=null;
var _136=null;
for(var ka=0;ka<_130.length;++ka){
_133=_130[ka].match(/(.*)(==|!=|===|!==|>|>=|<|<=)(.*)/);
att=_133[1];
comp=_133[2];
_136=_133[3];
if(!eval(_126[k][att]+comp+_136)){
_12e=false;
break;
}
}
if(_12e){
break;
}
}
}
}
btn.state("enabled",(!text||btn.text)&&_12e);
if(typeof cmd=="function"){
continue;
}
var _138=this.config.customSelects[cmd];
if((!text||btn.text)&&(typeof _138!="undefined")){
_138.refresh(this);
continue;
}
switch(cmd){
case "fontname":
case "fontsize":
if(!text){
try{
var _139=(""+doc.queryCommandValue(cmd)).toLowerCase();
if(!_139){
btn.element.selectedIndex=0;
break;
}
var _13a=this.config[cmd];
var _13b=0;
for(var j in _13a){
if((j.toLowerCase()==_139)||(_13a[j].substr(0,_139.length).toLowerCase()==_139)){
btn.element.selectedIndex=_13b;
throw "ok";
}
++_13b;
}
btn.element.selectedIndex=0;
}
catch(ex){
}
}
break;
case "formatblock":
var _13d=[];
for(var _13e in this.config.formatblock){
if(typeof this.config.formatblock[_13e]=="string"){
_13d[_13d.length]=this.config.formatblock[_13e];
}
}
var _13f=this._getFirstAncestor(this.getSelection(),_13d);
if(_13f){
for(var x=0;x<_13d.length;x++){
if(_13d[x].toLowerCase()==_13f.tagName.toLowerCase()){
btn.element.selectedIndex=x;
}
}
}else{
btn.element.selectedIndex=0;
}
break;
case "textindicator":
if(!text){
try{
var _141=btn.element.style;
_141.backgroundColor=Xinha._makeColor(doc.queryCommandValue(Xinha.is_ie?"backcolor":"hilitecolor"));
if(/transparent/i.test(_141.backgroundColor)){
_141.backgroundColor=Xinha._makeColor(doc.queryCommandValue("backcolor"));
}
_141.color=Xinha._makeColor(doc.queryCommandValue("forecolor"));
_141.fontFamily=doc.queryCommandValue("fontname");
_141.fontWeight=doc.queryCommandState("bold")?"bold":"normal";
_141.fontStyle=doc.queryCommandState("italic")?"italic":"normal";
}
catch(ex){
}
}
break;
case "htmlmode":
btn.state("active",text);
break;
case "lefttoright":
case "righttoleft":
var _142=this.getParentElement();
while(_142&&!Xinha.isBlockElement(_142)){
_142=_142.parentNode;
}
if(_142){
btn.state("active",(_142.style.direction==((cmd=="righttoleft")?"rtl":"ltr")));
}
break;
default:
cmd=cmd.replace(/(un)?orderedlist/i,"insert$1orderedlist");
try{
btn.state("active",(!text&&doc.queryCommandState(cmd)));
}
catch(ex){
}
break;
}
}
if(this._customUndo&&!this._timerUndo){
this._undoTakeSnapshot();
var _143=this;
this._timerUndo=setTimeout(function(){
_143._timerUndo=null;
},this.config.undoTimeout);
}
if(0&&Xinha.is_gecko){
var s=this.getSelection();
if(s&&s.isCollapsed&&s.anchorNode&&s.anchorNode.parentNode.tagName.toLowerCase()!="body"&&s.anchorNode.nodeType==3&&s.anchorOffset==s.anchorNode.length&&!(s.anchorNode.parentNode.nextSibling&&s.anchorNode.parentNode.nextSibling.nodeType==3)&&!Xinha.isBlockElement(s.anchorNode.parentNode)){
try{
s.anchorNode.parentNode.parentNode.insertBefore(this._doc.createTextNode("\t"),s.anchorNode.parentNode.nextSibling);
}
catch(ex){
}
}
}
for(var _145 in this.plugins){
var _146=this.plugins[_145].instance;
if(_146&&typeof _146.onUpdateToolbar=="function"){
_146.onUpdateToolbar();
}
}
};
Xinha.prototype.getAllAncestors=function(){
var p=this.getParentElement();
var a=[];
while(p&&(p.nodeType==1)&&(p.tagName.toLowerCase()!="body")){
a.push(p);
p=p.parentNode;
}
a.push(this._doc.body);
return a;
};
Xinha.prototype._getFirstAncestor=function(sel,_14a){
var prnt=this.activeElement(sel);
if(prnt===null){
try{
prnt=(Xinha.is_ie?this.createRange(sel).parentElement():this.createRange(sel).commonAncestorContainer);
}
catch(ex){
return null;
}
}
if(typeof _14a=="string"){
_14a=[_14a];
}
while(prnt){
if(prnt.nodeType==1){
if(_14a===null){
return prnt;
}
if(_14a.contains(prnt.tagName.toLowerCase())){
return prnt;
}
if(prnt.tagName.toLowerCase()=="body"){
break;
}
if(prnt.tagName.toLowerCase()=="table"){
break;
}
}
prnt=prnt.parentNode;
}
return null;
};
Xinha.prototype._getAncestorBlock=function(sel){
var prnt=(Xinha.is_ie?this.createRange(sel).parentElement:this.createRange(sel).commonAncestorContainer);
while(prnt&&(prnt.nodeType==1)){
switch(prnt.tagName.toLowerCase()){
case "div":
case "p":
case "address":
case "blockquote":
case "center":
case "del":
case "ins":
case "pre":
case "h1":
case "h2":
case "h3":
case "h4":
case "h5":
case "h6":
case "h7":
return prnt;
case "body":
case "noframes":
case "dd":
case "li":
case "th":
case "td":
case "noscript":
return null;
default:
break;
}
}
return null;
};
Xinha.prototype._createImplicitBlock=function(type){
var sel=this.getSelection();
if(Xinha.is_ie){
sel.empty();
}else{
sel.collapseToStart();
}
var rng=this.createRange(sel);
};
Xinha.prototype.surroundHTML=function(_151,_152){
var html=this.getSelectedHTML();
this.insertHTML(_151+html+_152);
};
Xinha.prototype.hasSelectedText=function(){
return this.getSelectedHTML()!=="";
};
Xinha.prototype._comboSelected=function(el,txt){
this.focusEditor();
var _156=el.options[el.selectedIndex].value;
switch(txt){
case "fontname":
case "fontsize":
this.execCommand(txt,false,_156);
break;
case "formatblock":
if(!_156){
this.updateToolbar();
break;
}
if(!Xinha.is_gecko||_156!=="blockquote"){
_156="<"+_156+">";
}
this.execCommand(txt,false,_156);
break;
default:
var _157=this.config.customSelects[txt];
if(typeof _157!="undefined"){
_157.action(this);
}else{
alert("FIXME: combo box "+txt+" not implemented");
}
break;
}
};
Xinha.prototype._colorSelector=function(_158){
var _159=this;
if(Xinha.is_gecko){
try{
_159._doc.execCommand("useCSS",false,false);
_159._doc.execCommand("styleWithCSS",false,true);
}
catch(ex){
}
}
var btn=_159._toolbarObjects[_158].element;
var _15b;
if(_158=="hilitecolor"){
if(Xinha.is_ie){
_158="backcolor";
_15b=Xinha._colorToRgb(_159._doc.queryCommandValue("backcolor"));
}else{
_15b=Xinha._colorToRgb(_159._doc.queryCommandValue("hilitecolor"));
}
}else{
_15b=Xinha._colorToRgb(_159._doc.queryCommandValue("forecolor"));
}
var _15c=function(_15d){
_159._doc.execCommand(_158,false,_15d);
};
if(Xinha.is_ie){
var _15e=_159.createRange(_159.getSelection());
_15c=function(_15f){
_15e.select();
_159._doc.execCommand(_158,false,_15f);
};
}
var _160=new Xinha.colorPicker({cellsize:_159.config.colorPickerCellSize,callback:_15c,granularity:_159.config.colorPickerGranularity,websafe:_159.config.colorPickerWebSafe,savecolors:_159.config.colorPickerSaveColors});
_160.open(_159.config.colorPickerPosition,btn,_15b);
};
Xinha.prototype.execCommand=function(_161,UI,_163){
var _164=this;
this.focusEditor();
_161=_161.toLowerCase();
if(this.firePluginEvent("onExecCommand",_161,UI,_163)){
this.updateToolbar();
return false;
}
switch(_161){
case "htmlmode":
this.setMode();
break;
case "hilitecolor":
case "forecolor":
this._colorSelector(_161);
break;
case "createlink":
this._createLink();
break;
case "undo":
case "redo":
if(this._customUndo){
this[_161]();
}else{
this._doc.execCommand(_161,UI,_163);
}
break;
case "inserttable":
this._insertTable();
break;
case "insertimage":
this._insertImage();
break;
case "about":
this._popupDialog(_164.config.URIs.about,null,this);
break;
case "showhelp":
this._popupDialog(_164.config.URIs.help,null,this);
break;
case "killword":
this._wordClean();
break;
case "cut":
case "copy":
case "paste":
this._doc.execCommand(_161,UI,_163);
if(this.config.killWordOnPaste){
this._wordClean();
}
break;
case "lefttoright":
case "righttoleft":
if(this.config.changeJustifyWithDirection){
this._doc.execCommand((_161=="righttoleft")?"justifyright":"justifyleft",UI,_163);
}
var dir=(_161=="righttoleft")?"rtl":"ltr";
var el=this.getParentElement();
while(el&&!Xinha.isBlockElement(el)){
el=el.parentNode;
}
if(el){
if(el.style.direction==dir){
el.style.direction="";
}else{
el.style.direction=dir;
}
}
break;
case "justifyleft":
case "justifyright":
_161.match(/^justify(.*)$/);
var ae=this.activeElement(this.getSelection());
if(ae&&ae.tagName.toLowerCase()=="img"){
ae.align=ae.align==RegExp.$1?"":RegExp.$1;
}else{
this._doc.execCommand(_161,UI,_163);
}
break;
default:
try{
this._doc.execCommand(_161,UI,_163);
}
catch(ex){
if(this.config.debug){
alert(ex+"\n\nby execCommand("+_161+");");
}
}
break;
}
this.updateToolbar();
return false;
};
Xinha.prototype._editorEvent=function(ev){
var _169=this;
if(typeof _169._textArea["on"+ev.type]=="function"){
_169._textArea["on"+ev.type]();
}
if(this.isKeyEvent(ev)){
if(_169.firePluginEvent("onKeyPress",ev)){
return false;
}
if(this.isShortCut(ev)){
this._shortCuts(ev);
}
}
if(ev.type=="mousedown"){
if(_169.firePluginEvent("onMouseDown",ev)){
return false;
}
}
if(_169._timerToolbar){
clearTimeout(_169._timerToolbar);
}
_169._timerToolbar=setTimeout(function(){
_169.updateToolbar();
_169._timerToolbar=null;
},250);
};
Xinha.prototype._shortCuts=function(ev){
var key=this.getKey(ev).toLowerCase();
var cmd=null;
var _16d=null;
switch(key){
case "b":
cmd="bold";
break;
case "i":
cmd="italic";
break;
case "u":
cmd="underline";
break;
case "s":
cmd="strikethrough";
break;
case "l":
cmd="justifyleft";
break;
case "e":
cmd="justifycenter";
break;
case "r":
cmd="justifyright";
break;
case "j":
cmd="justifyfull";
break;
case "z":
cmd="undo";
break;
case "y":
cmd="redo";
break;
case "v":
cmd="paste";
break;
case "n":
cmd="formatblock";
_16d="p";
break;
case "0":
cmd="killword";
break;
case "1":
case "2":
case "3":
case "4":
case "5":
case "6":
cmd="formatblock";
_16d="h"+key;
break;
}
if(cmd){
this.execCommand(cmd,false,_16d);
Xinha._stopEvent(ev);
}
};
Xinha.prototype.convertNode=function(el,_16f){
var _170=this._doc.createElement(_16f);
while(el.firstChild){
_170.appendChild(el.firstChild);
}
return _170;
};
Xinha.prototype.scrollToElement=function(e){
if(!e){
e=this.getParentElement();
if(!e){
return;
}
}
var _172=Xinha.getElementTopLeft(e);
this._iframe.contentWindow.scrollTo(_172.left,_172.top);
};
Xinha.prototype.getHTML=function(){
var html="";
switch(this._editMode){
case "wysiwyg":
if(!this.config.fullPage){
html=Xinha.getHTML(this._doc.body,false,this);
}else{
html=this.doctype+"\n"+Xinha.getHTML(this._doc.documentElement,true,this);
}
break;
case "textmode":
html=this._textArea.value;
break;
default:
alert("Mode <"+this._editMode+"> not defined!");
return false;
}
return html;
};
Xinha.prototype.outwardHtml=function(html){
for(var i in this.plugins){
var _176=this.plugins[i].instance;
if(_176&&typeof _176.outwardHtml=="function"){
html=_176.outwardHtml(html);
}
}
html=html.replace(/<(\/?)b(\s|>|\/)/ig,"<$1strong$2");
html=html.replace(/<(\/?)i(\s|>|\/)/ig,"<$1em$2");
html=html.replace(/<(\/?)strike(\s|>|\/)/ig,"<$1del$2");
html=html.replace("onclick=\"try{if(document.designMode &amp;&amp; document.designMode == 'on') return false;}catch(e){} window.open(","onclick=\"window.open(");
var _177=location.href.replace(/(https?:\/\/[^\/]*)\/.*/,"$1")+"/";
html=html.replace(/https?:\/\/null\//g,_177);
html=html.replace(/((href|src|background)=[\'\"])\/+/ig,"$1"+_177);
html=this.outwardSpecialReplacements(html);
html=this.fixRelativeLinks(html);
if(this.config.sevenBitClean){
html=html.replace(/[^ -~\r\n\t]/g,function(c){
return "&#"+c.charCodeAt(0)+";";
});
}
html=html.replace(/(<script[^>]*)(freezescript)/gi,"$1javascript");
if(this.config.fullPage){
html=Xinha.stripCoreCSS(html);
}
return html;
};
Xinha.prototype.inwardHtml=function(html){
for(var i in this.plugins){
var _17b=this.plugins[i].instance;
if(_17b&&typeof _17b.inwardHtml=="function"){
html=_17b.inwardHtml(html);
}
}
html=html.replace(/<(\/?)del(\s|>|\/)/ig,"<$1strike$2");
html=html.replace("onclick=\"window.open(","onclick=\"try{if(document.designMode &amp;&amp; document.designMode == 'on') return false;}catch(e){} window.open(");
html=this.inwardSpecialReplacements(html);
html=html.replace(/(<script[^>]*)(javascript)/gi,"$1freezescript");
var _17c=new RegExp("((href|src|background)=['\"])/+","gi");
html=html.replace(_17c,"$1"+location.href.replace(/(https?:\/\/[^\/]*)\/.*/,"$1")+"/");
html=this.fixRelativeLinks(html);
if(this.config.fullPage){
html=Xinha.addCoreCSS(html);
}
return html;
};
Xinha.prototype.outwardSpecialReplacements=function(html){
for(var i in this.config.specialReplacements){
var from=this.config.specialReplacements[i];
var to=i;
if(typeof from.replace!="function"||typeof to.replace!="function"){
continue;
}
var reg=new RegExp(from.replace(Xinha.RE_Specials,"\\$1"),"g");
html=html.replace(reg,to.replace(/\$/g,"$$$$"));
}
return html;
};
Xinha.prototype.inwardSpecialReplacements=function(html){
for(var i in this.config.specialReplacements){
var from=i;
var to=this.config.specialReplacements[i];
if(typeof from.replace!="function"||typeof to.replace!="function"){
continue;
}
var reg=new RegExp(from.replace(Xinha.RE_Specials,"\\$1"),"g");
html=html.replace(reg,to.replace(/\$/g,"$$$$"));
}
return html;
};
Xinha.prototype.fixRelativeLinks=function(html){
if(typeof this.config.expandRelativeUrl!="undefined"&&this.config.expandRelativeUrl){
var src=html.match(/(src|href)="([^"]*)"/gi);
}
var b=document.location.href;
if(src){
var url,url_m,relPath,base_m,absPath;
for(var i=0;i<src.length;++i){
url=src[i].match(/(src|href)="([^"]*)"/i);
url_m=url[2].match(/\.\.\//g);
if(url_m){
relPath=new RegExp("(.*?)(([^/]*/){"+url_m.length+"})[^/]*$");
base_m=b.match(relPath);
absPath=url[2].replace(/(\.\.\/)*/,base_m[1]);
html=html.replace(new RegExp(url[2].replace(Xinha.RE_Specials,"\\$1")),absPath);
}
}
}
if(typeof this.config.stripSelfNamedAnchors!="undefined"&&this.config.stripSelfNamedAnchors){
var _18c=new RegExp(document.location.href.replace(/&/g,"&amp;").replace(Xinha.RE_Specials,"\\$1")+"(#[^'\" ]*)","g");
html=html.replace(_18c,"$1");
}
if(typeof this.config.stripBaseHref!="undefined"&&this.config.stripBaseHref){
var _18d=null;
if(typeof this.config.baseHref!="undefined"&&this.config.baseHref!==null){
_18d=new RegExp("((href|src|background)=\")("+this.config.baseHref.replace(Xinha.RE_Specials,"\\$1")+")","g");
}else{
_18d=new RegExp("((href|src|background)=\")("+document.location.href.replace(/^(https?:\/\/[^\/]*)(.*)/,"$1").replace(Xinha.RE_Specials,"\\$1")+")","g");
}
html=html.replace(_18d,"$1");
}
return html;
};
Xinha.prototype.getInnerHTML=function(){
if(!this._doc.body){
return "";
}
var html="";
switch(this._editMode){
case "wysiwyg":
if(!this.config.fullPage){
html=this._doc.body.innerHTML;
}else{
html=this.doctype+"\n"+this._doc.documentElement.innerHTML;
}
break;
case "textmode":
html=this._textArea.value;
break;
default:
alert("Mode <"+this._editMode+"> not defined!");
return false;
}
return html;
};
Xinha.prototype.setHTML=function(html){
if(!this.config.fullPage){
this._doc.body.innerHTML=html;
}else{
this.setFullHTML(html);
}
this._textArea.value=html;
};
Xinha.prototype.setDoctype=function(_190){
this.doctype=_190;
};
Xinha._object=null;
Xinha.cloneObject=function(obj){
if(!obj){
return null;
}
var _192={};
if(obj.constructor.toString().match(/\s*function Array\(/)){
_192=obj.constructor();
}
if(obj.constructor.toString().match(/\s*function Function\(/)){
_192=obj;
}else{
for(var n in obj){
var node=obj[n];
if(typeof node=="object"){
_192[n]=Xinha.cloneObject(node);
}else{
_192[n]=node;
}
}
}
return _192;
};
Xinha.checkSupportedBrowser=function(){
if(Xinha.is_gecko){
if(navigator.productSub<20021201){
alert("You need at least Mozilla-1.3 Alpha.\nSorry, your Gecko is not supported.");
return false;
}
if(navigator.productSub<20030210){
alert("Mozilla < 1.3 Beta is not supported!\nI'll try, though, but it might not work.");
}
}
return Xinha.is_gecko||Xinha.ie_version>=5.5;
};
Xinha._eventFlushers=[];
Xinha.flushEvents=function(){
var x=0;
var e=Xinha._eventFlushers.pop();
while(e){
try{
if(e.length==3){
Xinha._removeEvent(e[0],e[1],e[2]);
x++;
}else{
if(e.length==2){
e[0]["on"+e[1]]=null;
e[0]._xinha_dom0Events[e[1]]=null;
x++;
}
}
}
catch(ex){
}
e=Xinha._eventFlushers.pop();
}
};
if(document.addEventListener){
Xinha._addEvent=function(el,_198,func){
el.addEventListener(_198,func,true);
Xinha._eventFlushers.push([el,_198,func]);
};
Xinha._removeEvent=function(el,_19b,func){
el.removeEventListener(_19b,func,true);
};
Xinha._stopEvent=function(ev){
ev.preventDefault();
ev.stopPropagation();
};
}else{
if(document.attachEvent){
Xinha._addEvent=function(el,_19f,func){
el.attachEvent("on"+_19f,func);
Xinha._eventFlushers.push([el,_19f,func]);
};
Xinha._removeEvent=function(el,_1a2,func){
el.detachEvent("on"+_1a2,func);
};
Xinha._stopEvent=function(ev){
try{
ev.cancelBubble=true;
ev.returnValue=false;
}
catch(ex){
}
};
}else{
Xinha._addEvent=function(el,_1a6,func){
alert("_addEvent is not supported");
};
Xinha._removeEvent=function(el,_1a9,func){
alert("_removeEvent is not supported");
};
Xinha._stopEvent=function(ev){
alert("_stopEvent is not supported");
};
}
}
Xinha._addEvents=function(el,evs,func){
for(var i=evs.length;--i>=0;){
Xinha._addEvent(el,evs[i],func);
}
};
Xinha._removeEvents=function(el,evs,func){
for(var i=evs.length;--i>=0;){
Xinha._removeEvent(el,evs[i],func);
}
};
Xinha.addDom0Event=function(el,ev,fn){
Xinha._prepareForDom0Events(el,ev);
el._xinha_dom0Events[ev].unshift(fn);
};
Xinha.prependDom0Event=function(el,ev,fn){
Xinha._prepareForDom0Events(el,ev);
el._xinha_dom0Events[ev].push(fn);
};
Xinha._prepareForDom0Events=function(el,ev){
if(typeof el._xinha_dom0Events=="undefined"){
el._xinha_dom0Events={};
Xinha.freeLater(el,"_xinha_dom0Events");
}
if(typeof el._xinha_dom0Events[ev]=="undefined"){
el._xinha_dom0Events[ev]=[];
if(typeof el["on"+ev]=="function"){
el._xinha_dom0Events[ev].push(el["on"+ev]);
}
el["on"+ev]=function(_1bc){
var a=el._xinha_dom0Events[ev];
var _1be=true;
for(var i=a.length;--i>=0;){
el._xinha_tempEventHandler=a[i];
if(el._xinha_tempEventHandler(_1bc)===false){
el._xinha_tempEventHandler=null;
_1be=false;
break;
}
el._xinha_tempEventHandler=null;
}
return _1be;
};
Xinha._eventFlushers.push([el,ev]);
}
};
Xinha.prototype.notifyOn=function(ev,fn){
if(typeof this._notifyListeners[ev]=="undefined"){
this._notifyListeners[ev]=[];
Xinha.freeLater(this,"_notifyListeners");
}
this._notifyListeners[ev].push(fn);
};
Xinha.prototype.notifyOf=function(ev,args){
if(this._notifyListeners[ev]){
for(var i=0;i<this._notifyListeners[ev].length;i++){
this._notifyListeners[ev][i](ev,args);
}
}
};
Xinha._removeClass=function(el,_1c6){
if(!(el&&el.className)){
return;
}
var cls=el.className.split(" ");
var ar=[];
for(var i=cls.length;i>0;){
if(cls[--i]!=_1c6){
ar[ar.length]=cls[i];
}
}
el.className=ar.join(" ");
};
Xinha._addClass=function(el,_1cb){
Xinha._removeClass(el,_1cb);
el.className+=" "+_1cb;
};
Xinha._hasClass=function(el,_1cd){
if(!(el&&el.className)){
return false;
}
var cls=el.className.split(" ");
for(var i=cls.length;i>0;){
if(cls[--i]==_1cd){
return true;
}
}
return false;
};
Xinha._blockTags=" body form textarea fieldset ul ol dl li div "+"p h1 h2 h3 h4 h5 h6 quote pre table thead "+"tbody tfoot tr td th iframe address blockquote ";
Xinha.isBlockElement=function(el){
return el&&el.nodeType==1&&(Xinha._blockTags.indexOf(" "+el.tagName.toLowerCase()+" ")!=-1);
};
Xinha._paraContainerTags=" body td th caption fieldset div";
Xinha.isParaContainer=function(el){
return el&&el.nodeType==1&&(Xinha._paraContainerTags.indexOf(" "+el.tagName.toLowerCase()+" ")!=-1);
};
Xinha._closingTags=" a abbr acronym address applet b bdo big blockquote button caption center cite code del dfn dir div dl em fieldset font form frameset h1 h2 h3 h4 h5 h6 i iframe ins kbd label legend map menu noframes noscript object ol optgroup pre q s samp script select small span strike strong style sub sup table textarea title tt u ul var ";
Xinha.needsClosingTag=function(el){
return el&&el.nodeType==1&&(Xinha._closingTags.indexOf(" "+el.tagName.toLowerCase()+" ")!=-1);
};
Xinha.htmlEncode=function(str){
if(typeof str.replace=="undefined"){
str=str.toString();
}
str=str.replace(/&/ig,"&amp;");
str=str.replace(/</ig,"&lt;");
str=str.replace(/>/ig,"&gt;");
str=str.replace(/\xA0/g,"&nbsp;");
str=str.replace(/\x22/g,"&quot;");
return str;
};
Xinha.prototype.stripBaseURL=function(_1d4){
if(this.config.baseHref===null||!this.config.stripBaseHref){
return _1d4;
}
var _1d5=this.config.baseHref.replace(/^(https?:\/\/[^\/]+)(.*)$/,"$1");
var _1d6=new RegExp(_1d5);
return _1d4.replace(_1d6,"");
};
String.prototype.trim=function(){
return this.replace(/^\s+/,"").replace(/\s+$/,"");
};
Xinha._makeColor=function(v){
if(typeof v!="number"){
return v;
}
var r=v&255;
var g=(v>>8)&255;
var b=(v>>16)&255;
return "rgb("+r+","+g+","+b+")";
};
Xinha._colorToRgb=function(v){
if(!v){
return "";
}
var r,g,b;
function hex(d){
return (d<16)?("0"+d.toString(16)):d.toString(16);
}
if(typeof v=="number"){
r=v&255;
g=(v>>8)&255;
b=(v>>16)&255;
return "#"+hex(r)+hex(g)+hex(b);
}
if(v.substr(0,3)=="rgb"){
var re=/rgb\s*\(\s*([0-9]+)\s*,\s*([0-9]+)\s*,\s*([0-9]+)\s*\)/;
if(v.match(re)){
r=parseInt(RegExp.$1,10);
g=parseInt(RegExp.$2,10);
b=parseInt(RegExp.$3,10);
return "#"+hex(r)+hex(g)+hex(b);
}
return null;
}
if(v.substr(0,1)=="#"){
return v;
}
return null;
};
Xinha.prototype._popupDialog=function(url,_1e0,init){
Dialog(this.popupURL(url),_1e0,init);
};
Xinha.prototype.imgURL=function(file,_1e3){
if(typeof _1e3=="undefined"){
return _editor_url+file;
}else{
return _editor_url+"plugins/"+_1e3+"/img/"+file;
}
};
Xinha.prototype.popupURL=function(file){
var url="";
if(file.match(/^plugin:\/\/(.*?)\/(.*)/)){
var _1e6=RegExp.$1;
var _1e7=RegExp.$2;
if(!(/\.html$/.test(_1e7))){
_1e7+=".html";
}
url=_editor_url+"plugins/"+_1e6+"/popups/"+_1e7;
}else{
if(file.match(/^\/.*?/)){
url=file;
}else{
url=_editor_url+this.config.popupURL+file;
}
}
return url;
};
Xinha.getElementById=function(tag,id){
var el,i,objs=document.getElementsByTagName(tag);
for(i=objs.length;--i>=0&&(el=objs[i]);){
if(el.id==id){
return el;
}
}
return null;
};
Xinha.prototype._toggleBorders=function(){
var _1eb=this._doc.getElementsByTagName("TABLE");
if(_1eb.length!==0){
if(!this.borders){
this.borders=true;
}else{
this.borders=false;
}
for(var i=0;i<_1eb.length;i++){
if(this.borders){
Xinha._addClass(_1eb[i],"htmtableborders");
}else{
Xinha._removeClass(_1eb[i],"htmtableborders");
}
}
}
return true;
};
Xinha.addCoreCSS=function(html){
var _1ee="<style title=\"Xinha Internal CSS\" type=\"text/css\">"+".htmtableborders, .htmtableborders td, .htmtableborders th {border : 1px dashed lightgrey ! important;}\n"+"html, body { border: 0px; } \n"+"body { background-color: #ffffff; } \n"+"</style>\n";
if(html&&/<head>/i.test(html)){
return html.replace(/<head>/i,"<head>"+_1ee);
}else{
if(html){
return _1ee+html;
}else{
return _1ee;
}
}
};
Xinha.stripCoreCSS=function(html){
return html.replace(/<style[^>]+title="Xinha Internal CSS"(.|\n)*?<\/style>/i,"");
};
Xinha.addClasses=function(el,_1f1){
if(el!==null){
var _1f2=el.className.trim().split(" ");
var ours=_1f1.split(" ");
for(var x=0;x<ours.length;x++){
var _1f5=false;
for(var i=0;_1f5===false&&i<_1f2.length;i++){
if(_1f2[i]==ours[x]){
_1f5=true;
}
}
if(_1f5===false){
_1f2[_1f2.length]=ours[x];
}
}
el.className=_1f2.join(" ").trim();
}
};
Xinha.removeClasses=function(el,_1f8){
var _1f9=el.className.trim().split();
var _1fa=[];
var _1fb=_1f8.trim().split();
for(var i=0;i<_1f9.length;i++){
var _1fd=false;
for(var x=0;x<_1fb.length&&!_1fd;x++){
if(_1f9[i]==_1fb[x]){
_1fd=true;
}
}
if(!_1fd){
_1fa[_1fa.length]=_1f9[i];
}
}
return _1fa.join(" ");
};
Xinha.addClass=Xinha._addClass;
Xinha.removeClass=Xinha._removeClass;
Xinha._addClasses=Xinha.addClasses;
Xinha._removeClasses=Xinha.removeClasses;
Xinha._postback=function(url,data,_201){
var req=null;
req=Xinha.getXMLHTTPRequestObject();
var _203="";
if(typeof data=="string"){
_203=data;
}else{
if(typeof data=="object"){
for(var i in data){
_203+=(_203.length?"&":"")+i+"="+encodeURIComponent(data[i]);
}
}
}
function callBack(){
if(req.readyState==4){
if(req.status==200||Xinha.isRunLocally&&req.status==0){
if(typeof _201=="function"){
_201(req.responseText,req);
}
}else{
alert("An error has occurred: "+req.statusText);
}
}
}
req.onreadystatechange=callBack;
req.open("POST",url,true);
req.setRequestHeader("Content-Type","application/x-www-form-urlencoded; charset=UTF-8");
req.send(_203);
};
Xinha._getback=function(url,_206){
var req=null;
req=Xinha.getXMLHTTPRequestObject();
function callBack(){
if(req.readyState==4){
if(req.status==200||Xinha.isRunLocally&&req.status==0){
_206(req.responseText,req);
}else{
alert("An error has occurred: "+req.statusText);
}
}
}
req.onreadystatechange=callBack;
req.open("GET",url,true);
req.send(null);
};
Xinha._geturlcontent=function(url){
var req=null;
req=Xinha.getXMLHTTPRequestObject();
req.open("GET",url,false);
req.send(null);
if(req.status==200||Xinha.isRunLocally&&req.status==0){
return req.responseText;
}else{
return "";
}
};
if(typeof dump=="undefined"){
function dump(o){
var s="";
for(var prop in o){
s+=prop+" = "+o[prop]+"\n";
}
var x=window.open("","debugger");
x.document.write("<pre>"+s+"</pre>");
}
}
Xinha.arrayContainsArray=function(a1,a2){
var _210=true;
for(var x=0;x<a2.length;x++){
var _212=false;
for(var i=0;i<a1.length;i++){
if(a1[i]==a2[x]){
_212=true;
break;
}
}
if(!_212){
_210=false;
break;
}
}
return _210;
};
Xinha.arrayFilter=function(a1,_215){
var _216=[];
for(var x=0;x<a1.length;x++){
if(_215(a1[x])){
_216[_216.length]=a1[x];
}
}
return _216;
};
Xinha.uniq_count=0;
Xinha.uniq=function(_218){
return _218+Xinha.uniq_count++;
};
Xinha._loadlang=function(_219,url){
var lang;
if(typeof _editor_lcbackend=="string"){
url=_editor_lcbackend;
url=url.replace(/%lang%/,_editor_lang);
url=url.replace(/%context%/,_219);
}else{
if(!url){
if(_219!="Xinha"){
url=_editor_url+"plugins/"+_219+"/lang/"+_editor_lang+".js";
}else{
url=_editor_url+"lang/"+_editor_lang+".js";
}
}
}
var _21c=Xinha._geturlcontent(url);
if(_21c!==""){
try{
eval("lang = "+_21c);
}
catch(ex){
alert("Error reading Language-File ("+url+"):\n"+Error.toString());
lang={};
}
}else{
lang={};
}
return lang;
};
Xinha._lc=function(_21d,_21e,_21f){
var url,ret;
if(typeof _21e=="object"&&_21e.url&&_21e.context){
url=_21e.url+_editor_lang+".js";
_21e=_21e.context;
}
var m=null;
if(typeof _21d=="string"){
m=_21d.match(/\$(.*?)=(.*?)\$/g);
}
if(m){
if(!_21f){
_21f={};
}
for(var i=0;i<m.length;i++){
var n=m[i].match(/\$(.*?)=(.*?)\$/);
_21f[n[1]]=n[2];
_21d=_21d.replace(n[0],"$"+n[1]);
}
}
if(_editor_lang=="en"){
if(typeof _21d=="object"&&_21d.string){
ret=_21d.string;
}else{
ret=_21d;
}
}else{
if(typeof Xinha._lc_catalog=="undefined"){
Xinha._lc_catalog=[];
}
if(typeof _21e=="undefined"){
_21e="Xinha";
}
if(typeof Xinha._lc_catalog[_21e]=="undefined"){
Xinha._lc_catalog[_21e]=Xinha._loadlang(_21e,url);
}
var key;
if(typeof _21d=="object"&&_21d.key){
key=_21d.key;
}else{
if(typeof _21d=="object"&&_21d.string){
key=_21d.string;
}else{
key=_21d;
}
}
if(typeof Xinha._lc_catalog[_21e][key]=="undefined"){
if(_21e=="Xinha"){
if(typeof _21d=="object"&&_21d.string){
ret=_21d.string;
}else{
ret=_21d;
}
}else{
return Xinha._lc(_21d,"Xinha",_21f);
}
}else{
ret=Xinha._lc_catalog[_21e][key];
}
}
if(typeof _21d=="object"&&_21d.replace){
_21f=_21d.replace;
}
if(typeof _21f!="undefined"){
for(var i in _21f){
ret=ret.replace("$"+i,_21f[i]);
}
}
return ret;
};
Xinha.hasDisplayedChildren=function(el){
var _226=el.childNodes;
for(var i=0;i<_226.length;i++){
if(_226[i].tagName){
if(_226[i].style.display!="none"){
return true;
}
}
}
return false;
};
Xinha._loadback=function(Url,_229,_22a,_22b){
var T=!Xinha.is_ie?"onload":"onreadystatechange";
var S=document.createElement("script");
S.type="text/javascript";
S.src=Url;
if(_229){
S[T]=function(){
if(Xinha.is_ie&&(!(/loaded|complete/.test(window.event.srcElement.readyState)))){
return;
}
_229.call(_22a?_22a:this,_22b);
S[T]=null;
};
}
document.getElementsByTagName("head")[0].appendChild(S);
};
Xinha.collectionToArray=function(_22e){
var _22f=[];
for(var i=0;i<_22e.length;i++){
_22f.push(_22e.item(i));
}
return _22f;
};
if(!Array.prototype.append){
Array.prototype.append=function(a){
for(var i=0;i<a.length;i++){
this.push(a[i]);
}
return this;
};
}
Xinha.makeEditors=function(_233,_234,_235){
if(typeof _234=="function"){
_234=_234();
}
var _236={};
for(var x=0;x<_233.length;x++){
var _238=new Xinha(_233[x],Xinha.cloneObject(_234));
_238.registerPlugins(_235);
_236[_233[x]]=_238;
}
return _236;
};
Xinha.startEditors=function(_239){
for(var i in _239){
if(_239[i].generate){
_239[i].generate();
}
}
};
Xinha.prototype.registerPlugins=function(_23b){
if(_23b){
for(var i=0;i<_23b.length;i++){
this.setLoadingMessage("Register plugin $plugin","Xinha",{"plugin":_23b[i]});
this.registerPlugin(eval(_23b[i]));
}
}
};
Xinha.base64_encode=function(_23d){
var _23e="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
var _23f="";
var chr1,chr2,chr3;
var enc1,enc2,enc3,enc4;
var i=0;
do{
chr1=_23d.charCodeAt(i++);
chr2=_23d.charCodeAt(i++);
chr3=_23d.charCodeAt(i++);
enc1=chr1>>2;
enc2=((chr1&3)<<4)|(chr2>>4);
enc3=((chr2&15)<<2)|(chr3>>6);
enc4=chr3&63;
if(isNaN(chr2)){
enc3=enc4=64;
}else{
if(isNaN(chr3)){
enc4=64;
}
}
_23f=_23f+_23e.charAt(enc1)+_23e.charAt(enc2)+_23e.charAt(enc3)+_23e.charAt(enc4);
}while(i<_23d.length);
return _23f;
};
Xinha.base64_decode=function(_243){
var _244="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
var _245="";
var chr1,chr2,chr3;
var enc1,enc2,enc3,enc4;
var i=0;
_243=_243.replace(/[^A-Za-z0-9\+\/\=]/g,"");
do{
enc1=_244.indexOf(_243.charAt(i++));
enc2=_244.indexOf(_243.charAt(i++));
enc3=_244.indexOf(_243.charAt(i++));
enc4=_244.indexOf(_243.charAt(i++));
chr1=(enc1<<2)|(enc2>>4);
chr2=((enc2&15)<<4)|(enc3>>2);
chr3=((enc3&3)<<6)|enc4;
_245=_245+String.fromCharCode(chr1);
if(enc3!=64){
_245=_245+String.fromCharCode(chr2);
}
if(enc4!=64){
_245=_245+String.fromCharCode(chr3);
}
}while(i<_243.length);
return _245;
};
Xinha.removeFromParent=function(el){
if(!el.parentNode){
return;
}
var pN=el.parentNode;
pN.removeChild(el);
return el;
};
Xinha.hasParentNode=function(el){
if(el.parentNode){
if(el.parentNode.nodeType==11){
return false;
}
return true;
}
return false;
};
Xinha.viewportSize=function(_24c){
_24c=(_24c)?_24c:window;
var x,y;
if(_24c.innerHeight){
x=_24c.innerWidth;
y=_24c.innerHeight;
}else{
if(_24c.document.documentElement&&_24c.document.documentElement.clientHeight){
x=_24c.document.documentElement.clientWidth;
y=_24c.document.documentElement.clientHeight;
}else{
if(_24c.document.body){
x=_24c.document.body.clientWidth;
y=_24c.document.body.clientHeight;
}
}
}
return {"x":x,"y":y};
};
Xinha.prototype.scrollPos=function(_24e){
_24e=(_24e)?_24e:window;
var x,y;
if(_24e.pageYOffset){
x=_24e.pageXOffset;
y=_24e.pageYOffset;
}else{
if(_24e.document.documentElement&&document.documentElement.scrollTop){
x=_24e.document.documentElement.scrollLeft;
y=_24e.document.documentElement.scrollTop;
}else{
if(_24e.document.body){
x=_24e.document.body.scrollLeft;
y=_24e.document.body.scrollTop;
}
}
}
return {"x":x,"y":y};
};
Xinha.getElementTopLeft=function(_250){
var _251={top:0,left:0};
while(_250){
_251.top+=_250.offsetTop;
_251.left+=_250.offsetLeft;
if(_250.offsetParent&&_250.offsetParent.tagName.toLowerCase()!="body"){
_250=_250.offsetParent;
}else{
_250=null;
}
}
return _251;
};
Xinha.findPosX=function(obj){
var _253=0;
if(obj.offsetParent){
return Xinha.getElementTopLeft(obj).left;
}else{
if(obj.x){
_253+=obj.x;
}
}
return _253;
};
Xinha.findPosY=function(obj){
var _255=0;
if(obj.offsetParent){
return Xinha.getElementTopLeft(obj).top;
}else{
if(obj.y){
_255+=obj.y;
}
}
return _255;
};
Xinha.prototype.setLoadingMessage=function(_256,_257,_258){
if(!this.config.showLoading||!document.getElementById("loading_sub_"+this._textArea.name)){
return;
}
var elt=document.getElementById("loading_sub_"+this._textArea.name);
elt.innerHTML=Xinha._lc(_256,_257,_258);
};
Xinha.prototype.removeLoadingMessage=function(){
if(!this.config.showLoading||!document.getElementById("loading_"+this._textArea.name)){
return;
}
document.body.removeChild(document.getElementById("loading_"+this._textArea.name));
};
Xinha.toFree=[];
Xinha.freeLater=function(obj,prop){
Xinha.toFree.push({o:obj,p:prop});
};
Xinha.free=function(obj,prop){
if(obj&&!prop){
for(var p in obj){
Xinha.free(obj,p);
}
}else{
if(obj){
try{
obj[prop]=null;
}
catch(x){
}
}
}
};
Xinha.collectGarbageForIE=function(){
Xinha.flushEvents();
for(var x=0;x<Xinha.toFree.length;x++){
Xinha.free(Xinha.toFree[x].o,Xinha.toFree[x].p);
Xinha.toFree[x].o=null;
}
};
Xinha.prototype.insertNodeAtSelection=function(_260){
Xinha.notImplemented("insertNodeAtSelection");
};
Xinha.prototype.getParentElement=function(sel){
Xinha.notImplemented("getParentElement");
};
Xinha.prototype.activeElement=function(sel){
Xinha.notImplemented("activeElement");
};
Xinha.prototype.selectionEmpty=function(sel){
Xinha.notImplemented("selectionEmpty");
};
Xinha.prototype.selectNodeContents=function(node,pos){
Xinha.notImplemented("selectNodeContents");
};
Xinha.prototype.insertHTML=function(html){
Xinha.notImplemented("insertHTML");
};
Xinha.prototype.getSelectedHTML=function(){
Xinha.notImplemented("getSelectedHTML");
};
Xinha.prototype.getSelection=function(){
Xinha.notImplemented("getSelection");
};
Xinha.prototype.createRange=function(sel){
Xinha.notImplemented("createRange");
};
Xinha.prototype.isKeyEvent=function(_268){
Xinha.notImplemented("isKeyEvent");
};
Xinha.prototype.isShortCut=function(_269){
if(_269.ctrlKey&&!_269.altKey){
return true;
}
return false;
};
Xinha.prototype.getKey=function(_26a){
Xinha.notImplemented("getKey");
};
Xinha.getOuterHTML=function(_26b){
Xinha.notImplemented("getOuterHTML");
};
Xinha.getXMLHTTPRequestObject=function(){
try{
if(typeof XMLHttpRequest=="function"){
return new XMLHttpRequest();
}else{
if(typeof ActiveXObject=="function"){
return new ActiveXObject("Microsoft.XMLHTTP");
}
}
}
catch(e){
Xinha.notImplemented("getXMLHTTPRequestObject");
}
};
Xinha.prototype._activeElement=function(sel){
return this.activeElement(sel);
};
Xinha.prototype._selectionEmpty=function(sel){
return this.selectionEmpty(sel);
};
Xinha.prototype._getSelection=function(){
return this.getSelection();
};
Xinha.prototype._createRange=function(sel){
return this.createRange(sel);
};
HTMLArea=Xinha;
Xinha.init();
Xinha.addDom0Event(window,"unload",Xinha.collectGarbageForIE);
Xinha.notImplemented=function(_26f){
throw new Error("Method Not Implemented","Part of Xinha has tried to call the "+_26f+" method which has not been implemented.");
};

