/*----------------------------------------------------------------------------\
|                                 Timer Class                                 |
|-----------------------------------------------------------------------------|
|                         Created by Erik Arvidsson                           |
|                  (http://webfx.eae.net/contact.html#erik)                   |
|                      For WebFX (http://webfx.eae.net/)                      |
|-----------------------------------------------------------------------------|
| Object Oriented Encapsulation  of setTimeout  fires ontimer when the  timer |
| is triggered. Does not work in IE 5.00                                      |
|-----------------------------------------------------------------------------|
|                   Copyright (c) 2002, 2006 Erik Arvidsson                   |
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
| 2006-05-28 | Changed license to Apache Software License 2.0.                |
|-----------------------------------------------------------------------------|
| Created 2002-10-14 | All changes are in the log above. | Updated 2006-05-28 |
\----------------------------------------------------------------------------*/

function Timer(nPauseTime) {
	this._pauseTime = typeof nPauseTime == "undefined" ? 1000 : nPauseTime;
	this._timer = null;
	this._isStarted = false;
}

Timer.prototype.start = function () {
	if (this.isStarted())
		this.stop();
	var oThis = this;
	this._timer = window.setTimeout(function () {
		if (typeof oThis.ontimer == "function")
			oThis.ontimer();
	}, this._pauseTime);
	this._isStarted = false;
};

Timer.prototype.stop = function () {
	if (this._timer != null)
		window.clearTimeout(this._timer);
	this._isStarted = false;
};

Timer.prototype.isStarted = function () {
	return this._isStarted;
};

Timer.prototype.getPauseTime = function () {
	return this._pauseTime;
};

Timer.prototype.setPauseTime = function (nPauseTime) {
	this._pauseTime = nPauseTime;
};
