public class Abraca.PlaylistWidget : Gtk.ScrolledWindow {
	public PlaylistWidget (Client client, Config config)
	{
		hscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
		vscrollbar_policy = Gtk.PolicyType.AUTOMATIC;

		shadow_type = Gtk.ShadowType.IN;

		var model = new PlaylistModel(client);

		add(new PlaylistView(model, client, config));

		show_all ();
	}
}