import java.awt.*;

public class GrayPanel extends Panel
{
	public void paint(Graphics g)
	{
	g.setColor(Util.body);
	g.fillRect(0, 0, size().width, size().height);
	}
}
