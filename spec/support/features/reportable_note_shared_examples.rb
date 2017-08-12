require 'spec_helper'

shared_examples 'reportable note' do |type|
  include NotesHelper

  let(:comment) { find("##{ActionView::RecordIdentifier.dom_id(note)}") }
  let(:more_actions_selector) { '.more-actions.dropdown' }
  let(:abuse_report_path) { new_abuse_report_path(user_id: note.author.id, ref_url: noteable_note_url(note)) }

  it 'has a `More actions` dropdown' do
    expect(comment).to have_selector(more_actions_selector)
  end

  it 'dropdown has Edit, Report and Delete links' do
    dropdown = comment.find(more_actions_selector)
    open_dropdown(dropdown)

    if type == 'issue'
      expect(dropdown).to have_button('Edit comment')
      expect(dropdown).to have_button('Delete comment')
    else
      expect(dropdown).to have_link('Edit comment')
      expect(dropdown).to have_link('Delete comment')
    end

    expect(dropdown).to have_link('Report as abuse', href: abuse_report_path)
  end

  it 'Report button links to a report page' do
    dropdown = comment.find(more_actions_selector)
    open_dropdown(dropdown)

    dropdown.click_link('Report as abuse')

    expect(find('#user_name')['value']).to match(note.author.username)
    expect(find('#abuse_report_message')['value']).to match(noteable_note_url(note))
  end

  def open_dropdown(dropdown)
    dropdown.click
    dropdown.find('.dropdown-menu li', match: :first)
  end
end
