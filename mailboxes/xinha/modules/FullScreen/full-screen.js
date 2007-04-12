function FullScreen(_1,_2){
this.editor=_1;
_1._superclean_on=false;
cfg=_1.config;
cfg.registerButton("fullscreen",this._lc("Maximize/Minimize Editor"),[_editor_url+cfg.imgURL+"ed_buttons_main.gif",8,0],true,function(e,_4,_5){
e._fullScreen();
});
cfg.addToolbarElement("fullscreen","popupeditor",0);
}
FullScreen._pluginInfo={name:"FullScreen",version:"1.0",developer:"James Sleeman",developer_url:"http://www.gogo.co.nz/",c_owner:"Gogo Internet Services",license:"htmlArea",sponsor:"Gogo Internet Services",sponsor_url:"http://www.gogo.co.nz/"};
FullScreen.prototype._lc=function(_6){
return Xinha._lc(_6,{url:_editor_url+"modules/FullScreen/lang/",context:"FullScreen"});
};
Xinha.prototype._fullScreen=function(){
var e=this;
function sizeItUp(){
if(!e._isFullScreen||e._sizing){
return false;
}
e._sizing=true;
var _8=Xinha.viewportSize();
var h=_8.y-e.config.fullScreenMargins[0]-e.config.fullScreenMargins[2];
var w=_8.x-e.config.fullScreenMargins[1]-e.config.fullScreenMargins[3];
e.sizeEditor(w+"px",h+"px",true,true);
e._sizing=false;
if(e._toolbarObjects.fullscreen){
e._toolbarObjects.fullscreen.swapImage([_editor_url+cfg.imgURL+"ed_buttons_main.gif",9,0]);
}
}
function sizeItDown(){
if(e._isFullScreen||e._sizing){
return false;
}
e._sizing=true;
e.initSize();
e._sizing=false;
if(e._toolbarObjects.fullscreen){
e._toolbarObjects.fullscreen.swapImage([_editor_url+cfg.imgURL+"ed_buttons_main.gif",8,0]);
}
}
function resetScroll(){
if(e._isFullScreen){
window.scroll(0,0);
window.setTimeout(resetScroll,150);
}
}
if(typeof this._isFullScreen=="undefined"){
this._isFullScreen=false;
if(e.target!=e._iframe){
Xinha._addEvent(window,"resize",sizeItUp);
}
}
if(Xinha.is_gecko){
this.deactivateEditor();
}
if(this._isFullScreen){
this._htmlArea.style.position="";
if(!Xinha.is_ie){
this._htmlArea.style.border="";
}
try{
if(Xinha.is_ie&&document.compatMode=="CSS1Compat"){
var _b=document.getElementsByTagName("html");
}else{
var _b=document.getElementsByTagName("body");
}
_b[0].style.overflow="";
}
catch(e){
}
this._isFullScreen=false;
sizeItDown();
var _c=this._htmlArea;
while((_c=_c.parentNode)&&_c.style){
_c.style.position=_c._xinha_fullScreenOldPosition;
_c._xinha_fullScreenOldPosition=null;
}
if(Xinha.ie_version<7){
var _d=document.getElementsByTagName("select");
for(var i=0;i<_d.length;++i){
_d[i].style.visibility="visible";
}
}
window.scroll(this._unScroll.x,this._unScroll.y);
}else{
this._unScroll={x:(window.pageXOffset)?(window.pageXOffset):(document.documentElement)?document.documentElement.scrollLeft:document.body.scrollLeft,y:(window.pageYOffset)?(window.pageYOffset):(document.documentElement)?document.documentElement.scrollTop:document.body.scrollTop};
var _c=this._htmlArea;
while((_c=_c.parentNode)&&_c.style){
_c._xinha_fullScreenOldPosition=_c.style.position;
_c.style.position="static";
}
if(Xinha.ie_version<7){
var _d=document.getElementsByTagName("select");
var s,currentEditor;
for(var i=0;i<_d.length;++i){
s=_d[i];
currentEditor=false;
while(s=s.parentNode){
if(s==this._htmlArea){
currentEditor=true;
break;
}
}
if(!currentEditor&&_d[i].style.visibility!="hidden"){
_d[i].style.visibility="hidden";
}
}
}
window.scroll(0,0);
this._htmlArea.style.position="absolute";
this._htmlArea.style.zIndex=999;
this._htmlArea.style.left=e.config.fullScreenMargins[3]+"px";
this._htmlArea.style.top=e.config.fullScreenMargins[0]+"px";
if(!Xinha.is_ie){
this._htmlArea.style.border="none";
}
this._isFullScreen=true;
resetScroll();
try{
if(Xinha.is_ie&&document.compatMode=="CSS1Compat"){
var _b=document.getElementsByTagName("html");
}else{
var _b=document.getElementsByTagName("body");
}
_b[0].style.overflow="hidden";
}
catch(e){
}
sizeItUp();
}
if(Xinha.is_gecko){
this.activateEditor();
}
this.focusEditor();
};

