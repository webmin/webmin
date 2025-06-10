/*----------------------------------------------------------------------------\
|                                Range Class                                  |
|-----------------------------------------------------------------------------|
|                         Created by Erik Arvidsson                           |
|                  (http://webfx.eae.net/contact.html#erik)                   |
|                      For WebFX (http://webfx.eae.net/)                      |
|-----------------------------------------------------------------------------|
| Used to  model the data  used  when working  with  sliders,  scrollbars and |
| progress bars.  Based  on  the  ideas of  the javax.swing.BoundedRangeModel |
| interface  defined  by  Sun  for  Java;   http://java.sun.com/products/jfc/ |
| swingdoc-api-1.0.3/com/sun/java/swing/BoundedRangeModel.html                |
|-----------------------------------------------------------------------------|
|                Copyright (c) 2002, 2005, 2006 Erik Arvidsson                |
|-----------------------------------------------------------------------------|
| Licensed under the Apache License, Version 2.0 (the "License"); you may not |
| use this file except in compliance with the License.  You may obtain a copy |
| of the License at http://www.apache.org/licenses/LICENSE-2.0                |
| - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - |
| Unless  required  by  applicable law or  agreed  to  in  writing,  software |
| distributed under the License is distributed on an  "AS IS" BASIS,  WITHOUT |
| WARRANTIES OR  CONDITIONS OF ANY KIND,  either express or implied.  See the |
| License  for the  specific language  governing permissions  and limitations |
| under the License.                                                          |
|-----------------------------------------------------------------------------|
| 2002-10-14 | Original version released                                      |
| 2005-10-27 | Use Math.round instead of Math.floor                           |
| 2006-05-28 | Changed license to Apache Software License 2.0.                |
|-----------------------------------------------------------------------------|
| Created 2002-10-14 | All changes are in the log above. | Updated 2006-05-28 |
\----------------------------------------------------------------------------*/


function Range() {
	this._value = 0;
	this._minimum = 0;
	this._maximum = 100;
	this._extent = 0;

	this._isChanging = false;
}

Range.prototype.setValue = function (value) {
	value = Math.round(parseFloat(value));
	if (isNaN(value)) return;
	if (this._value != value) {
		if (value + this._extent > this._maximum)
			this._value = this._maximum - this._extent;
		else if (value < this._minimum)
			this._value = this._minimum;
		else
			this._value = value;
		if (!this._isChanging && typeof this.onchange == "function")
			 this.onchange();
	}
};

Range.prototype.getValue = function () {
	return this._value;
};

Range.prototype.setExtent = function (extent) {
	if (this._extent != extent) {
		if (extent < 0)
			this._extent = 0;
		else if (this._value + extent > this._maximum)
			this._extent = this._maximum - this._value;
		else
			this._extent = extent;
		if (!this._isChanging && typeof this.onchange == "function")
			this.onchange();
	}
};

Range.prototype.getExtent = function () {
	return this._extent;
};

Range.prototype.setMinimum = function (minimum) {
	if (this._minimum != minimum) {
		var oldIsChanging = this._isChanging;
		this._isChanging = true;

		this._minimum = minimum;

		if (minimum > this._value)
			this.setValue(minimum);
		if (minimum > this._maximum) {
			this._extent = 0;
			this.setMaximum(minimum);
			this.setValue(minimum)
		}
		if (minimum + this._extent > this._maximum)
			this._extent = this._maximum - this._minimum;

		this._isChanging = oldIsChanging;
		if (!this._isChanging && typeof this.onchange == "function")
			this.onchange();
	}
};

Range.prototype.getMinimum = function () {
	return this._minimum;
};

Range.prototype.setMaximum = function (maximum) {
	if (this._maximum != maximum) {
		var oldIsChanging = this._isChanging;
		this._isChanging = true;

		this._maximum = maximum;

		if (maximum < this._value)
			this.setValue(maximum - this._extent);
		if (maximum < this._minimum) {
			this._extent = 0;
			this.setMinimum(maximum);
			this.setValue(this._maximum);
		}
		if (maximum < this._minimum + this._extent)
			this._extent = this._maximum - this._minimum;
		if (maximum < this._value + this._extent)
			this._extent = this._maximum - this._value;

		this._isChanging = oldIsChanging;
		if (!this._isChanging && typeof this.onchange == "function")
			this.onchange();
	}
};

Range.prototype.getMaximum = function () {
	return this._maximum;
};
