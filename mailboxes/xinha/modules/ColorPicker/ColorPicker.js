ColorPicker._pluginInfo={name:"colorPicker",version:"1.0",developer:"James Sleeman",developer_url:"http://www.gogo.co.nz/",c_owner:"Gogo Internet Services",license:"htmlArea",sponsor:"Gogo Internet Services",sponsor_url:"http://www.gogo.co.nz/"};
function ColorPicker(){
}
Xinha.colorPicker=function(_1){
if(Xinha.colorPicker.savedColors.length===0){
Xinha.colorPicker.loadColors();
}
var _2=this;
var _3=false;
var _4=false;
var _5=0;
var _6=0;
this.callback=_1.callback?_1.callback:function(_7){
alert("You picked "+_7);
};
this.websafe=_1.websafe?_1.websafe:false;
this.savecolors=_1.savecolors?_1.savecolors:20;
this.cellsize=parseInt(_1.cellsize?_1.cellsize:"10px",10);
this.side=_1.granularity?_1.granularity:18;
var _8=this.side+1;
var _9=this.side-1;
this.value=1;
this.saved_cells=null;
this.table=document.createElement("table");
this.table.className="dialog";
this.table.cellSpacing=this.table.cellPadding=0;
this.table.onmouseup=function(){
_3=false;
_4=false;
};
this.tbody=document.createElement("tbody");
this.table.appendChild(this.tbody);
this.table.style.border="1px solid WindowFrame";
this.table.style.zIndex="1000";
var tr=document.createElement("tr");
var td=document.createElement("td");
td.colSpan=this.side;
td.className="title";
td.style.fontFamily="small-caption,caption,sans-serif";
td.style.fontSize="x-small";
td.appendChild(document.createTextNode(Xinha._lc("Click a color...")));
td.style.borderBottom="1px solid WindowFrame";
tr.appendChild(td);
td=null;
var td=document.createElement("td");
td.className="title";
td.colSpan=2;
td.style.fontFamily="Tahoma,Verdana,sans-serif";
td.style.borderBottom="1px solid WindowFrame";
td.style.paddingRight="0";
tr.appendChild(td);
var _c=document.createElement("div");
_c.title=Xinha._lc("Close");
_c.className="buttonColor";
_c.style.height="11px";
_c.style.width="11px";
_c.style.cursor="pointer";
_c.onclick=function(){
_2.close();
};
_c.appendChild(document.createTextNode("\xd7"));
_c.align="center";
_c.style.verticalAlign="top";
_c.style.position="relative";
_c.style.cssFloat="right";
_c.style.styleFloat="right";
_c.style.padding="0";
_c.style.margin="2px";
_c.style.backgroundColor="transparent";
_c.style.fontSize="11px";
if(!Xinha.is_ie){
_c.style.lineHeight="9px";
}
_c.style.letterSpacing="0";
td.appendChild(_c);
this.tbody.appendChild(tr);
_c=tr=td=null;
this.constrain_cb=document.createElement("input");
this.constrain_cb.type="checkbox";
this.chosenColor=document.createElement("input");
this.chosenColor.type="text";
this.chosenColor.maxLength=7;
this.chosenColor.style.width="50px";
this.chosenColor.style.fontSize="11px";
this.chosenColor.onchange=function(){
if(/#[0-9a-f]{6,6}/i.test(this.value)){
_2.backSample.style.backgroundColor=this.value;
_2.foreSample.style.color=this.value;
}
};
this.backSample=document.createElement("div");
this.backSample.appendChild(document.createTextNode("\xa0"));
this.backSample.style.fontWeight="bold";
this.backSample.style.fontFamily="small-caption,caption,sans-serif";
this.backSample.fontSize="x-small";
this.foreSample=document.createElement("div");
this.foreSample.appendChild(document.createTextNode(Xinha._lc("Sample")));
this.foreSample.style.fontWeight="bold";
this.foreSample.style.fontFamily="small-caption,caption,sans-serif";
this.foreSample.fontSize="x-small";
function toHex(_d){
var h=_d.toString(16);
if(h.length<2){
h="0"+h;
}
return h;
}
function tupleToColor(_f){
return "#"+toHex(_f.red)+toHex(_f.green)+toHex(_f.blue);
}
function nearestPowerOf(num,_11){
return Math.round(Math.round(num/_11)*_11);
}
function doubleHexDec(dec){
return parseInt(dec.toString(16)+dec.toString(16),16);
}
function rgbToWebsafe(_13){
_13.red=doubleHexDec(nearestPowerOf(parseInt(toHex(_13.red).charAt(0),16),3));
_13.blue=doubleHexDec(nearestPowerOf(parseInt(toHex(_13.blue).charAt(0),16),3));
_13.green=doubleHexDec(nearestPowerOf(parseInt(toHex(_13.green).charAt(0),16),3));
return _13;
}
function hsvToRGB(h,s,v){
var _17;
if(s===0){
_17={red:v,green:v,blue:v};
}else{
h/=60;
var i=Math.floor(h);
var f=h-i;
var p=v*(1-s);
var q=v*(1-s*f);
var t=v*(1-s*(1-f));
switch(i){
case 0:
_17={red:v,green:t,blue:p};
break;
case 1:
_17={red:q,green:v,blue:p};
break;
case 2:
_17={red:p,green:v,blue:t};
break;
case 3:
_17={red:p,green:q,blue:v};
break;
case 4:
_17={red:t,green:p,blue:v};
break;
default:
_17={red:v,green:p,blue:q};
break;
}
}
_17.red=Math.ceil(_17.red*255);
_17.green=Math.ceil(_17.green*255);
_17.blue=Math.ceil(_17.blue*255);
return _17;
}
this.open=function(_1d,_1e,_1f){
this.table.style.display="";
this.pick_color();
if(_1f&&/#[0-9a-f]{6,6}/i.test(_1f)){
this.chosenColor.value=_1f;
this.backSample.style.backgroundColor=_1f;
this.foreSample.style.color=_1f;
}
this.table.style.position="absolute";
var e=_1e;
var top=0;
var _22=0;
do{
top+=e.offsetTop;
_22+=e.offsetLeft;
e=e.offsetParent;
}while(e);
var x,y;
if(/top/.test(_1d)){
if(top-this.table.offsetHeight>0){
this.table.style.top=(top-this.table.offsetHeight)+"px";
}else{
this.table.style.top=0;
}
}else{
this.table.style.top=(top+_1e.offsetHeight)+"px";
}
if(/left/.test(_1d)){
this.table.style.left=_22+"px";
}else{
if(_22-(this.table.offsetWidth-_1e.offsetWidth)>0){
this.table.style.left=(_22-(this.table.offsetWidth-_1e.offsetWidth))+"px";
}else{
this.table.style.left=0;
}
}
};
function pickCell(_24){
_2.chosenColor.value=_24.colorCode;
_2.backSample.style.backgroundColor=_24.colorCode;
_2.foreSample.style.color=_24.colorCode;
if((_24.hue>=195&&_24.saturation>0.5)||(_24.hue===0&&_24.saturation===0&&_24.value<0.5)||(_24.hue!==0&&_2.value<0.75)){
_24.style.borderColor="#fff";
}else{
_24.style.borderColor="#000";
}
_5=_24.thisrow;
_6=_24.thiscol;
}
function pickValue(_25){
if(_2.value<0.5){
_25.style.borderColor="#fff";
}else{
_25.style.borderColor="#000";
}
_9=_25.thisrow;
_8=_25.thiscol;
_2.chosenColor.value=_2.saved_cells[_5][_6].colorCode;
_2.backSample.style.backgroundColor=_2.saved_cells[_5][_6].colorCode;
_2.foreSample.style.color=_2.saved_cells[_5][_6].colorCode;
}
function unpickCell(row,col){
_2.saved_cells[row][col].style.borderColor=_2.saved_cells[row][col].colorCode;
}
this.pick_color=function(){
var _28,cols;
var _29=this;
var _2a=359/(this.side);
var _2b=1/(this.side-1);
var _2c=1/(this.side-1);
var _2d=this.constrain_cb.checked;
if(this.saved_cells===null){
this.saved_cells=[];
for(var row=0;row<this.side;row++){
var tr=document.createElement("tr");
this.saved_cells[row]=[];
for(var col=0;col<this.side;col++){
var td=document.createElement("td");
if(_2d){
td.colorCode=tupleToColor(rgbToWebsafe(hsvToRGB(_2a*row,_2b*col,this.value)));
}else{
td.colorCode=tupleToColor(hsvToRGB(_2a*row,_2b*col,this.value));
}
this.saved_cells[row][col]=td;
td.style.height=this.cellsize+"px";
td.style.width=this.cellsize-2+"px";
td.style.borderWidth="1px";
td.style.borderStyle="solid";
td.style.borderColor=td.colorCode;
td.style.backgroundColor=td.colorCode;
if(row==_5&&col==_6){
td.style.borderColor="#000";
this.chosenColor.value=td.colorCode;
this.backSample.style.backgroundColor=td.colorCode;
this.foreSample.style.color=td.colorCode;
}
td.hue=_2a*row;
td.saturation=_2b*col;
td.thisrow=row;
td.thiscol=col;
td.onmousedown=function(){
_3=true;
_29.saved_cells[_5][_6].style.borderColor=_29.saved_cells[_5][_6].colorCode;
pickCell(this);
};
td.onmouseover=function(){
if(_3){
pickCell(this);
}
};
td.onmouseout=function(){
if(_3){
this.style.borderColor=this.colorCode;
}
};
td.ondblclick=function(){
Xinha.colorPicker.remember(this.colorCode,_29.savecolors);
_29.callback(this.colorCode);
_29.close();
};
td.appendChild(document.createTextNode(" "));
td.style.cursor="pointer";
tr.appendChild(td);
td=null;
}
var td=document.createElement("td");
td.appendChild(document.createTextNode(" "));
td.style.width=this.cellsize+"px";
tr.appendChild(td);
td=null;
var td=document.createElement("td");
this.saved_cells[row][col+1]=td;
td.appendChild(document.createTextNode(" "));
td.style.width=this.cellsize-2+"px";
td.style.height=this.cellsize+"px";
td.constrainedColorCode=tupleToColor(rgbToWebsafe(hsvToRGB(0,0,_2c*row)));
td.style.backgroundColor=td.colorCode=tupleToColor(hsvToRGB(0,0,_2c*row));
td.style.borderWidth="1px";
td.style.borderStyle="solid";
td.style.borderColor=td.colorCode;
if(row==_9){
td.style.borderColor="black";
}
td.hue=_2a*row;
td.saturation=_2b*col;
td.hsv_value=_2c*row;
td.thisrow=row;
td.thiscol=col+1;
td.onmousedown=function(){
_4=true;
_29.saved_cells[_9][_8].style.borderColor=_29.saved_cells[_9][_8].colorCode;
_29.value=this.hsv_value;
_29.pick_color();
pickValue(this);
};
td.onmouseover=function(){
if(_4){
_29.value=this.hsv_value;
_29.pick_color();
pickValue(this);
}
};
td.onmouseout=function(){
if(_4){
this.style.borderColor=this.colorCode;
}
};
td.style.cursor="pointer";
tr.appendChild(td);
td=null;
this.tbody.appendChild(tr);
tr=null;
}
var tr=document.createElement("tr");
this.saved_cells[row]=[];
for(var col=0;col<this.side;col++){
var td=document.createElement("td");
if(_2d){
td.colorCode=tupleToColor(rgbToWebsafe(hsvToRGB(0,0,_2c*(this.side-col-1))));
}else{
td.colorCode=tupleToColor(hsvToRGB(0,0,_2c*(this.side-col-1)));
}
this.saved_cells[row][col]=td;
td.style.height=this.cellsize+"px";
td.style.width=this.cellsize-2+"px";
td.style.borderWidth="1px";
td.style.borderStyle="solid";
td.style.borderColor=td.colorCode;
td.style.backgroundColor=td.colorCode;
td.hue=0;
td.saturation=0;
td.value=_2c*(this.side-col-1);
td.thisrow=row;
td.thiscol=col;
td.onmousedown=function(){
_3=true;
_29.saved_cells[_5][_6].style.borderColor=_29.saved_cells[_5][_6].colorCode;
pickCell(this);
};
td.onmouseover=function(){
if(_3){
pickCell(this);
}
};
td.onmouseout=function(){
if(_3){
this.style.borderColor=this.colorCode;
}
};
td.ondblclick=function(){
Xinha.colorPicker.remember(this.colorCode,_29.savecolors);
_29.callback(this.colorCode);
_29.close();
};
td.appendChild(document.createTextNode(" "));
td.style.cursor="pointer";
tr.appendChild(td);
td=null;
}
this.tbody.appendChild(tr);
tr=null;
var tr=document.createElement("tr");
var td=document.createElement("td");
tr.appendChild(td);
td.colSpan=this.side+2;
td.style.padding="3px";
if(this.websafe){
var div=document.createElement("div");
var _33=document.createElement("label");
_33.appendChild(document.createTextNode(Xinha._lc("Web Safe: ")));
this.constrain_cb.onclick=function(){
_29.pick_color();
};
_33.appendChild(this.constrain_cb);
_33.style.fontFamily="small-caption,caption,sans-serif";
_33.style.fontSize="x-small";
div.appendChild(_33);
td.appendChild(div);
div=null;
}
var div=document.createElement("div");
var _33=document.createElement("label");
_33.style.fontFamily="small-caption,caption,sans-serif";
_33.style.fontSize="x-small";
_33.appendChild(document.createTextNode(Xinha._lc("Color: ")));
_33.appendChild(this.chosenColor);
div.appendChild(_33);
var but=document.createElement("span");
but.className="buttonColor ";
but.style.fontSize="13px";
but.style.width="24px";
but.style.marginLeft="2px";
but.style.padding="0px 4px";
but.style.cursor="pointer";
but.onclick=function(){
Xinha.colorPicker.remember(_29.chosenColor.value,_29.savecolors);
_29.callback(_29.chosenColor.value);
_29.close();
};
but.appendChild(document.createTextNode("OK"));
but.align="center";
div.appendChild(but);
td.appendChild(div);
var _35=document.createElement("table");
_35.style.width="100%";
var _36=document.createElement("tbody");
_35.appendChild(_36);
var _37=document.createElement("tr");
_36.appendChild(_37);
var _38=document.createElement("td");
_37.appendChild(_38);
_38.appendChild(this.backSample);
_38.style.width="50%";
var _39=document.createElement("td");
_37.appendChild(_39);
_39.appendChild(this.foreSample);
_39.style.width="50%";
td.appendChild(_35);
var _3a=document.createElement("div");
_3a.style.clear="both";
function createSavedColors(_3b){
var _3c=false;
var div=document.createElement("div");
div.style.width=_29.cellsize+"px";
div.style.height=_29.cellsize+"px";
div.style.margin="1px";
div.style.border="1px solid black";
div.style.cursor="pointer";
div.style.backgroundColor=_3b;
div.style[_3c?"styleFloat":"cssFloat"]="left";
div.ondblclick=function(){
_29.callback(_3b);
_29.close();
};
div.onclick=function(){
_29.chosenColor.value=_3b;
_29.backSample.style.backgroundColor=_3b;
_29.foreSample.style.color=_3b;
};
_3a.appendChild(div);
}
for(var _3e=0;_3e<Xinha.colorPicker.savedColors.length;_3e++){
createSavedColors(Xinha.colorPicker.savedColors[_3e]);
}
td.appendChild(_3a);
this.tbody.appendChild(tr);
document.body.appendChild(this.table);
}else{
for(var row=0;row<this.side;row++){
for(var col=0;col<this.side;col++){
if(_2d){
this.saved_cells[row][col].colorCode=tupleToColor(rgbToWebsafe(hsvToRGB(_2a*row,_2b*col,this.value)));
}else{
this.saved_cells[row][col].colorCode=tupleToColor(hsvToRGB(_2a*row,_2b*col,this.value));
}
this.saved_cells[row][col].style.backgroundColor=this.saved_cells[row][col].colorCode;
this.saved_cells[row][col].style.borderColor=this.saved_cells[row][col].colorCode;
}
}
var _3f=this.saved_cells[_5][_6];
this.chosenColor.value=_3f.colorCode;
this.backSample.style.backgroundColor=_3f.colorCode;
this.foreSample.style.color=_3f.colorCode;
if((_3f.hue>=195&&_3f.saturation>0.5)||(_3f.hue===0&&_3f.saturation===0&&_3f.value<0.5)||(_3f.hue!==0&&_29.value<0.75)){
_3f.style.borderColor="#fff";
}else{
_3f.style.borderColor="#000";
}
}
};
this.close=function(){
this.table.style.display="none";
};
};
Xinha.colorPicker.savedColors=[];
Xinha.colorPicker.remember=function(_40,_41){
for(var i=Xinha.colorPicker.savedColors.length;i--;){
if(Xinha.colorPicker.savedColors[i]==_40){
return false;
}
}
Xinha.colorPicker.savedColors.splice(0,0,_40);
Xinha.colorPicker.savedColors=Xinha.colorPicker.savedColors.slice(0,_41);
var _43=new Date();
_43.setMonth(_43.getMonth()+1);
document.cookie="XinhaColorPicker="+escape(Xinha.colorPicker.savedColors.join("-"))+";expires="+_43.toGMTString();
return true;
};
Xinha.colorPicker.loadColors=function(){
var _44=document.cookie.indexOf("XinhaColorPicker");
if(_44!=-1){
var _45=(document.cookie.indexOf("=",_44)+1);
var end=document.cookie.indexOf(";",_44);
if(end==-1){
end=document.cookie.length;
}
Xinha.colorPicker.savedColors=unescape(document.cookie.substring(_45,end)).split("-");
}
};
Xinha.colorPicker._lc=function(_47){
return Xinha._lc(_47);
};

