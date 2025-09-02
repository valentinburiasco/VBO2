# frozen_string_literal: true
class BidirectionalLinksGenerator < Jekyll::Generator
  def generate(site)
    graph_nodes = []
    graph_edges = []

    all_notes = site.collections['posts'].docs
    all_pages = site.pages
    all_docs  = all_notes + all_pages

    link_extension = site.config["use_html_extension"] ? '.html' : ''

    # Convert all Wiki/Roam-style double-bracket links to HTML
    all_docs.each do |current_note|
      all_docs.each do |note_potentially_linked_to|
        # Defensive: skip if this doc has no basename (e.g. layouts, error pages)
        next unless note_potentially_linked_to.respond_to?(:basename)

        basename = note_potentially_linked_to.basename.to_s
        ext      = File.extname(basename)
        stem     = File.basename(basename, ext)

        note_title_regexp_pattern = Regexp.escape(stem)
          .gsub('\_', '[ _]')
          .gsub('\-', '[ -]')
          .capitalize

        title_from_data = note_potentially_linked_to.data['title']
        title_from_data = title_from_data ? Regexp.escape(title_from_data.to_s) : nil

        new_href   = "#{site.baseurl}#{note_potentially_linked_to.url}#{link_extension}"
        anchor_tag = "<a class='internal-link' href='#{new_href}'>\\1</a>"

        # Replace links of form [[filename|label]]
        current_note.content = current_note.content.gsub(
          /\[\[#{note_title_regexp_pattern}\|(.+?)(?=\])\]\]/i,
          anchor_tag
        )

        # Replace links of form [[title|label]]
        if title_from_data
          current_note.content = current_note.content.gsub(
            /\[\[#{title_from_data}\|(.+?)(?=\])\]\]/i,
            anchor_tag
          )
        end

        # Replace links of form [[title]]
        if title_from_data
          current_note.content = current_note.content.gsub(
            /\[\[(#{title_from_data})\]\]/i,
            anchor_tag
          )
        end

        # Replace links of form [[filename]]
        current_note.content = current_note.content.gsub(
          /\[\[(#{note_title_regexp_pattern})\]\]/i,
          anchor_tag
        )
      end

      # Remaining double-brackets are invalid → mark as broken links
      current_note.content = current_note.content.gsub(
        /\[\[([^\]]+)\]\]/i,
        <<~HTML.delete("\n")
          <span title='There is no note that matches this link.' class='invalid-link'>
            <span class='invalid-link-brackets'>[[</span>
            \\1
            <span class='invalid-link-brackets'>]]</span>
          </span>
        HTML
      )
    end

    # Identify backlinks + build graph
    all_notes.each do |current_note|
      notes_linking_to_current_note = all_notes.filter do |e|
        e.url != current_note.url && e.content.include?(current_note.url)
      end

      # Graph nodes
      unless current_note.path&.include?('_posts/index.html')
        graph_nodes << {
          id: note_id_from_note(current_note),
          path: "#{site.baseurl}#{current_note.url}#{link_extension}",
          label: current_note.data['title'],
        }
      end

      # Backlinks for Jekyll
      current_note.data['backlinks'] = notes_linking_to_current_note

      # Graph edges
      notes_linking_to_current_note.each do |n|
        graph_edges << {
          source: note_id_from_note(n),
          target: note_id_from_note(current_note),
        }
      end
    end

    File.write('_includes/posts_graph.json', JSON.dump({
      edges: graph_edges,
      nodes: graph_nodes,
    }))
  end

  def note_id_from_note(note)
    # Defensive: fallback to basename if no title
    (note.data['title'] || note.basename.to_s).bytes.join
  end
end
