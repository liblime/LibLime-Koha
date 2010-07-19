// waitTime is in milliseconds.
var ScreenSaver = function (waitTime) {
	this.lastActivity = new Date().getTime();
	this.waitTime = waitTime;

	var $this = this;
	this._timer = setInterval(function () { $this._checkTime.call($this) }, 1000);
	document.onmousemove = function () { $this._mouseHandler.call($this) };
};

ScreenSaver.prototype = {
	_timer: null,

	lastActivity: 0,
	started: false,
	waitTime: 0,

	onstart: function () {},
	onend: function () {},

	dispose: function () {
		if (this._timer) clearInterval(this._timer);
		document.onmousemove = null;
	},

	_checkTime: function () {
		if (!this.started && new Date().getTime() - this.lastActivity >= this.waitTime) {
			this.started = true;
			this.onstart();
		}
	},

	_mouseHandler: function () {
		this.lastActivity = new Date().getTime();
		if (this.started) {
			this.started = false;
			this.onend();
		}
	}
};

/*********** Begin Example ***********

var ss = new ScreenSaver(5000);

ss.onstart = function () {
	document.getElementsByTagName("body")[0].style.backgroundColor = "#000";
};

ss.onend = function () {
	document.getElementsByTagName("body")[0].style.backgroundColor = "#fff";
};

************* End Example *************/