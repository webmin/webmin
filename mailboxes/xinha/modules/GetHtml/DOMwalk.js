function GetHtmlImplementation(_1){
this.editor=_1;
}
GetHtmlImplementation._pluginInfo={name:"GetHtmlImplementation DOMwalk",origin:"Xinha Core",version:"$LastChangedRevision: 742 $".replace(/^[^:]*: (.*) \$$/,"$1"),developer:"The Xinha Core Developer Team",developer_url:"$HeadURL: http://svn.xinha.python-hosting.com/tags/0.92beta/modules/GetHtml/DOMwalk.js $".replace(/^[^:]*: (.*) \$$/,"$1"),sponsor:"",sponsor_url:"",license:"htmlArea"};
Xinha.getHTML=function(_2,_3,_4){
try{
return Xinha.getHTMLWrapper(_2,_3,_4);
}
catch(ex){
alert(Xinha._lc("Your Document is not well formed. Check JavaScript console for details."));
return _4._iframe.contentWindow.document.body.innerHTML;
}
};
Xinha.emptyAttributes=" checked disabled ismap readonly nowrap compact declare selected defer multiple noresize noshade ";
Xinha.getHTMLWrapper=function(_5,_6,_7,_8){
var _9="";
if(!_8){
_8="";
}
switch(_5.nodeType){
case 10:
case 6:
case 12:
break;
case 2:
break;
case 4:
_9+=(Xinha.is_ie?("\n"+_8):"")+"<![CDATA["+_5.data+"]]>";
break;
case 5:
_9+="&"+_5.nodeValue+";";
break;
case 7:
_9+=(Xinha.is_ie?("\n"+_8):"")+"<?"+_5.target+" "+_5.data+" ?>";
break;
case 1:
case 11:
case 9:
var _a;
var i;
var _c=(_5.nodeType==1)?_5.tagName.toLowerCase():"";
if((_c=="script"||_c=="noscript")&&_7.config.stripScripts){
break;
}
if(_6){
_6=!(_7.config.htmlRemoveTags&&_7.config.htmlRemoveTags.test(_c));
}
if(Xinha.is_ie&&_c=="head"){
if(_6){
_9+=(Xinha.is_ie?("\n"+_8):"")+"<head>";
}
var _d=RegExp.multiline;
RegExp.multiline=true;
var _e=_5.innerHTML.replace(Xinha.RE_tagName,function(_f,p1,p2){
return p1+p2.toLowerCase();
});
RegExp.multiline=_d;
_9+=_e+"\n";
if(_6){
_9+=(Xinha.is_ie?("\n"+_8):"")+"</head>";
}
break;
}else{
if(_6){
_a=(!(_5.hasChildNodes()||Xinha.needsClosingTag(_5)));
_9+=(Xinha.is_ie&&Xinha.isBlockElement(_5)?("\n"+_8):"")+"<"+_5.tagName.toLowerCase();
var _12=_5.attributes;
for(i=0;i<_12.length;++i){
var a=_12.item(i);
if(typeof a.nodeValue=="object"){
continue;
}
if(_5.tagName.toLowerCase()=="input"&&_5.type.toLowerCase()=="checkbox"&&a.nodeName.toLowerCase()=="value"&&a.nodeValue.toLowerCase()=="on"){
continue;
}
if(!a.specified&&!(_5.tagName.toLowerCase().match(/input|option/)&&a.nodeName=="value")&&!(_5.tagName.toLowerCase().match(/area/)&&a.nodeName.match(/shape|coords/i))){
continue;
}
var _14=a.nodeName.toLowerCase();
if(/_moz_editor_bogus_node/.test(_14)){
_9="";
break;
}
if(/(_moz)|(contenteditable)|(_msh)/.test(_14)){
continue;
}
var _15;
if(Xinha.emptyAttributes.indexOf(" "+_14+" ")!=-1){
_15=_14;
}else{
if(_14!="style"){
if(typeof _5[a.nodeName]!="undefined"&&_14!="href"&&_14!="src"&&!(/^on/.test(_14))){
_15=_5[a.nodeName];
}else{
_15=a.nodeValue;
if(Xinha.is_ie&&(_14=="href"||_14=="src")){
_15=_7.stripBaseURL(_15);
}
if(_7.config.only7BitPrintablesInURLs&&(_14=="href"||_14=="src")){
_15=_15.replace(/([^!-~]+)/g,function(_16){
return escape(_16);
});
}
}
}else{
if(!Xinha.is_ie){
_15=_5.style.cssText.replace(/rgb\(.*?\)/ig,function(rgb){
return Xinha._colorToRgb(rgb);
});
}
}
}
if(/^(_moz)?$/.test(_15)){
continue;
}
_9+=" "+_14+"=\""+Xinha.htmlEncode(_15)+"\"";
}
if(Xinha.is_ie&&_5.style.cssText){
_9+=" style=\""+_5.style.cssText.toLowerCase()+"\"";
}
if(Xinha.is_ie&&_5.tagName.toLowerCase()=="option"&&_5.selected){
_9+=" selected=\"selected\"";
}
if(_9!==""){
if(_a&&_c=="p"){
_9+=">&nbsp;</p>";
}else{
if(_a){
_9+=" />";
}else{
_9+=">";
}
}
}
}
}
var _18=false;
if(_c=="script"||_c=="noscript"){
if(!_7.config.stripScripts){
if(Xinha.is_ie){
var _19="\n"+_5.innerHTML.replace(/^[\n\r]*/,"").replace(/\s+$/,"")+"\n"+_8;
}else{
var _19=(_5.hasChildNodes())?_5.firstChild.nodeValue:"";
}
_9+=_19+"</"+_c+">"+((Xinha.is_ie)?"\n":"");
}
}else{
for(i=_5.firstChild;i;i=i.nextSibling){
if(!_18&&i.nodeType==1&&Xinha.isBlockElement(i)){
_18=true;
}
_9+=Xinha.getHTMLWrapper(i,true,_7,_8+"  ");
}
if(_6&&!_a){
_9+=(Xinha.is_ie&&Xinha.isBlockElement(_5)&&_18?("\n"+_8):"")+"</"+_5.tagName.toLowerCase()+">";
}
}
break;
case 3:
_9=/^script|noscript|style$/i.test(_5.parentNode.tagName)?_5.data:Xinha.htmlEncode(_5.data);
break;
case 8:
_9="<!--"+_5.data+"-->";
break;
}
return _9;
};

