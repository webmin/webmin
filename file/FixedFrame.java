import java.awt.*;
import java.io.*;

public class FixedFrame extends Frame
{
	int mw = 0, mh = 0;

	public FixedFrame()
	{
	Dimension d = Util.tk.getScreenSize();
	double rx = Math.random(), ry = Math.random();
	move((int)((d.width/2)*rx), (int)((d.height/2)*ry));
	}

	public FixedFrame(int w, int h)
	{
	this();
	mw = w; mh = h;
	}

	public boolean handleEvent(Event evt)
	{
	if (evt.target == this && evt.id == Event.WINDOW_DESTROY) {
		dispose();
		return true;
		}
	return super.handleEvent(evt);
	}

	public Dimension minimumSize()
	{
	if (mw != 0 && mh != 0) return new Dimension(mw, mh);
	else return super.minimumSize();
	}

	public Dimension preferredSize()
	{
	return minimumSize();
	}

	public void setFixedSize(int w, int h)
	{
	mw = w; mh = h;
	}
}

