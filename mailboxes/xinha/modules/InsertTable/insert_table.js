InsertTable._pluginInfo={name:"InsertTable",origin:"Xinha Core",version:"$LastChangedRevision: 688 $".replace(/^[^:]*: (.*) \$$/,"$1"),developer:"The Xinha Core Developer Team",developer_url:"$HeadURL: http://svn.xinha.python-hosting.com/trunk/modules/InsertTable/insert_table.js $".replace(/^[^:]*: (.*) \$$/,"$1"),sponsor:"",sponsor_url:"",license:"htmlArea"};
function InsertTable(_1){
}
Xinha.prototype._insertTable=function(){
var _2=this.getSelection();
var _3=this.createRange(_2);
var _4=this;
Dialog(_4.config.URIs.insert_table,function(_5){
if(!_5){
return false;
}
var _6=_4._doc;
var _7=_6.createElement("table");
for(var _8 in _5){
var _9=_5[_8];
if(!_9){
continue;
}
switch(_8){
case "f_width":
_7.style.width=_9+_5.f_unit;
break;
case "f_align":
_7.align=_9;
break;
case "f_border":
_7.border=parseInt(_9,10);
break;
case "f_spacing":
_7.cellSpacing=parseInt(_9,10);
break;
case "f_padding":
_7.cellPadding=parseInt(_9,10);
break;
}
}
var _a=0;
if(_5.f_fixed){
_a=Math.floor(100/parseInt(_5.f_cols,10));
}
var _b=_6.createElement("tbody");
_7.appendChild(_b);
for(var i=0;i<_5.f_rows;++i){
var tr=_6.createElement("tr");
_b.appendChild(tr);
for(var j=0;j<_5.f_cols;++j){
var td=_6.createElement("td");
if(_a){
td.style.width=_a+"%";
}
tr.appendChild(td);
td.appendChild(_6.createTextNode("\xa0"));
}
}
if(Xinha.is_ie){
_3.pasteHTML(_7.outerHTML);
}else{
_4.insertNodeAtSelection(_7);
}
return true;
},null);
};

