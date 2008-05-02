using GLib;

namespace Abraca {
	public class PlaylistModel : Gtk.ListStore, Gtk.TreeModel {
		/* Metadata resolve status */

		enum Status {
			UNRESOLVED,
			RESOLVING,
			RESOLVED
		}

		enum Column {
			STATUS,
			ID,
			POSITION_INDICATOR,
			ARTIST,
			ALBUM,
			GENRE,
			INFO
		}

		/** current playback status */
		public int playback_status {
			get; set; default = Xmms.PlaybackStatus.STOP;
		}

		/** current playlist displayed */
		public string active_playlist {
			get; set; default = "";
		}

		/** have we scrolled to current position? */
		private bool _have_scrolled;

		/** keep track of current playlist position */
		private Gtk.TreeRowReference _position = null;

		/** keep track of playlist position <-> medialib id */
		private PlaylistMap playlist_map;

		construct {
			Client c = Client.instance();

			set_column_types(new GLib.Type[8] {
					typeof(int),
					typeof(uint),
					typeof(int),
					typeof(string),
					typeof(string),
					typeof(string),
					typeof(string),
					typeof(string)
			});

			playlist_map = new PlaylistMap();

			c.playlist_loaded += on_playlist_loaded;

			c.playlist_add += on_playlist_add;
			c.playlist_move += on_playlist_move;
			c.playlist_insert += on_playlist_insert;
			c.playlist_remove += on_playlist_remove;
			c.playlist_position += on_playlist_position;

			c.playback_status += on_playback_status;

			c.collection_rename += on_collection_rename;

			c.medialib_entry_changed += (client,res) => {
				on_medialib_info(res);
			};
		}


		/**
		 * When GTK asks for the value of a column, check if the row
		 * has been resolved or not, otherwise resolve it.
		 */
		public void get_value(Gtk.TreeIter iter, int column, ref GLib.Value val) {
			GLib.Value tmp1, tmp2;

			base.get_value(iter, Column.STATUS, ref tmp1);
			if (((Status)tmp1.get_int()) == Status.UNRESOLVED) {
				Client c = Client.instance();

				base.get_value(iter, Column.ID, ref tmp2);
				//GLib.stdout.printf("unresolved crap %d\n", tmp2.get_uint());

				set(iter, Column.STATUS, Status.RESOLVING);

				c.xmms.medialib_get_info(tmp2.get_uint()).notifier_set(
					on_medialib_info
				);
			}

			base.get_value(iter, column, ref val);
		}

		/**
		 * Removes the row when an entry has been removed from the playlist.
		 */
		private void on_playlist_remove(Client c, string playlist, int pos) {
			Gtk.TreePath path;
			Gtk.TreeIter iter;

			if (playlist != active_playlist) {
				return;
			}

			path = new Gtk.TreePath.from_indices(pos, -1);
			if (get_iter(out iter, path)) {
				uint mid;

				get(iter, Column.ID, out mid);

				playlist_map.remove(mid, path);
				remove(iter);
			}
		}

		/**
		 * TODO: Move row x to pos y.
		 */
		private void on_playlist_move(Client c, string playlist, int pos, int npos) {
			Gtk.TreeIter iter, niter;
			if (iter_nth_child (out iter, null, pos) &&
			    iter_nth_child(out niter, null, npos)) {
				if (pos < npos) {
					move_after (iter, niter);
				} else {
					move_before (iter, niter);
				}
			}
		}


		/**
		 * Update the position indicator to point at the
		 * current playing entry.
		 */
		private void on_playlist_position(Client c, string playlist, int pos) {
			Gtk.TreeIter iter;

			/* Remove the old position indicator */
			if (_position.valid()) {
				get_iter(out iter, _position.get_path());
				set(iter, Column.POSITION_INDICATOR, 0);
			}


			/* Playlist is probably empty */
			if (pos < 0)
				return;

			/* Add the new position indicator */
			if (iter_nth_child (out iter, null, (int) pos)) {
				Gtk.TreePath path;
				uint mid;

				/* Notify the Client of the current medialib id */
				get(iter, Column.ID, out mid);
				c.set_playlist_id(mid);

				set(
					iter,
					Column.POSITION_INDICATOR,
					Gtk.STOCK_GO_FORWARD
				);

				path = get_path(iter);

				_position = new Gtk.TreeRowReference(this, path);

				/*
				if (!_have_scrolled) {
					scroll_to_cell(path, null, true, (float) 0.25, (float) 0);
					_have_scrolled = true;
				}
				*/
			}
		}

		/**
		 * Insert a row when a new entry has been inserted in the playlist.
		 */
		private void on_playlist_insert(Client c, string playlist, uint mid, int pos) {
			Gtk.TreePath path;
			Gtk.TreeIter iter;

			if (playlist != active_playlist) {
				return;
			}

			path = new Gtk.TreePath.from_indices(pos, -1);
			if (get_iter(out iter, path)) {
				Gtk.TreeIter added;

				insert_before (out added, iter);

				set(added, Column.STATUS, Status.UNRESOLVED, Column.ID, mid);

				Gtk.TreePath path = get_path(added);
				Gtk.TreeRowReference row = new Gtk.TreeRowReference(this, path);
				playlist_map.insert(mid, row);
			}
		}

		/**
		 * Keep track of status so we know what to do when an item has been clicked.
		 */
		private void on_playback_status(Client c, int status) {
			playback_status = status;

			/* Notify the Client of the current medialib id */
			if (_position.valid()) {
				Gtk.TreeIter iter;
				uint mid;

				get_iter(out iter, _position.get_path());
				get(iter, Column.ID, out mid);

				c.set_playlist_id(mid);
			}
		}

		/**
		 * Keep track of the name of the current playlist so we can filter out
		 * non-interesting playlist related updates.
		 */
		private void on_collection_rename(Client c, string name, string newname, string ns) {
			if (name != active_playlist) {
				return;
			}

			active_playlist = newname;
		}

		/**
		 * Called when xmms2 has loaded a new playlist, simply requests
		 * the mids of that playlist.
		 */
		private void on_playlist_loaded(Client c, string name) {
			active_playlist = name;
			_have_scrolled = false;

			c.xmms.playlist_list_entries(name).notifier_set(
				on_playlist_list_entries
			);
		}

		private void on_playlist_add(Client c, string playlist, uint mid) {
			Gtk.TreeRowReference row;
			Gtk.TreePath path;
			Gtk.TreeIter iter;

			if (playlist != active_playlist) {
				return;
			}

			append(out iter);
			set(iter, Column.STATUS, Status.UNRESOLVED, Column.ID, mid);

			path = get_path(iter);
			row = new Gtk.TreeRowReference(this, path);

			playlist_map.insert(mid, row);
		}

		/**
		 * Refresh the whole playlist.
		 */
		[InstanceLast]
		private void on_playlist_list_entries(Xmms.Result #res) {
			Client c = Client.instance();
			Gtk.TreeIter iter, sibling;
			bool first = true;

			playlist_map.clear();
			clear();

			/* disconnect our model while the shit hits the fan */
			/*
			set_model(null);
			*/

			for (res.list_first(); res.list_valid(); res.list_next()) {
				Gtk.TreeRowReference row;
				Gtk.TreePath path;
				uint mid;
				int pos;

				if (!res.get_uint(out mid))
					continue;

				if (first) {
					insert_after(out iter, null);
					first = !first;
				} else {
					insert_after(out iter, sibling);
				}

				set(iter, Column.STATUS, Status.UNRESOLVED, Column.ID, mid);

				sibling = iter;

				path = get_path(iter);
				row = new Gtk.TreeRowReference(this, path);

				playlist_map.insert(mid, row);
			}

			/* reconnect the model again */
			/*
			set_model(ore);
			*/
		}

		private void on_medialib_info(Xmms.Result #res) {
			weak GLib.SList<Gtk.TreeRowReference> lst;
			weak string artist, album, title, genre;
			int duration, dur_min, dur_sec, pos, id;
			string info;
			int mid;

			res.get_dict_entry_int("id", out mid);

			lst = playlist_map.lookup(mid);
			if (lst == null) {
				// the given mid doesn't match any of our rows 
				return;
			}

			if (!res.get_dict_entry_int("duration", out duration)) {
				duration = 0;
			}

			dur_min = duration / 60000;
			dur_sec = (duration % 60000) / 1000;

			if (!res.get_dict_entry_string("album", out album)) {
				album = _("Unknown");
			}
			if (!res.get_dict_entry_string("genre", out genre)) {
				genre = _("Unknown");
			}

			if (res.get_dict_entry_string("title", out title)) {
				if (!res.get_dict_entry_string("artist", out artist)) {
					artist = _("Unknown");
				}

				if (dur_min > 0 || dur_sec > 0) {
					info = GLib.Markup.printf_escaped(
						_("<b>%s</b> - <small>%d:%02d</small>\n" +
						"<small>by</small> %s <small>from</small> %s"),
						title, dur_min, dur_sec, artist, album
					);
				} else {
					info = GLib.Markup.printf_escaped(
						_("<b>%s</b>\n" +
						"<small>by</small> %s <small>from</small> %s"),
						title, artist, album
					);
				}
			} else {
				weak string url;

				res.get_dict_entry_string("url", out url);

				if (dur_min > 0 || dur_sec > 0) {
					info = GLib.Markup.printf_escaped(
						_("<b>%s</b> - <small>%d:%02d</small>"),
						url, dur_min, dur_sec
					);
				} else {
					info = GLib.Markup.printf_escaped(
						_("<b>%s</b>"),
						url
					);
				}
			}


			foreach (weak Gtk.TreeRowReference row in lst) {
				weak Gtk.TreePath path;
				Gtk.TreeIter iter;

				path = row.get_path();

				if (!row.valid() || !get_iter(out iter, path)) {
					GLib.stdout.printf("row not valid\n");
					continue;
				}

				set(iter,
					Column.INFO, info,
					Column.ARTIST, artist,
					Column.ALBUM, album,
					Column.GENRE, genre
				);
			}
		}
	}
}