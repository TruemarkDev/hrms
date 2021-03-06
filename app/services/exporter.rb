# frozen_string_literal: true

class Exporter
  attr_accessor :metadata, :archive_path, :errors

  PERSON_FIELDS_TO_EXPORT = %i[
    name
    city
    phone
    skype
    linkedin
    primary_tech
    english
    day_of_birth
    email
    skills
    current_position
    github
    personal_email
  ].freeze

  def initialize(start_time: nil, end_time: nil)
    @start_time = start_time
    @end_time = end_time
    @errors = []
  end

  def perform
    collect_data && archive_data
  end

  def collect_data
    @metadata_fields_types = {
      person: PERSON_FIELDS_TO_EXPORT.map { |attr| { name: attr, type: Person.columns_hash[attr.to_s].type } }
    }

    attachments = Attachment.where('name ILIKE ?', '%cv%')

    if @start_time.present? && @end_time.present?
      Rails.logger.debug("[EXPORT] Collecting data for time range: #{@start_time}..#{@end_time}")
      attachments = attachments.where(created_at: @start_time..@end_time)
    else
      Rails.logger.debug("[EXPORT] Collecting all data (time range not specified)")
    end

    @metadata = attachments.includes(:person).order(:created_at).map do |a|
      {
        id: a.file.id,
        name: a.file_filename.gsub(' ', '_'),
        content_type: a.file_content_type,
        path: "#{a.file.backend.directory}/#{a.file.id}",
        metadata: {
          person: PERSON_FIELDS_TO_EXPORT.each_with_object({}) { |attr, res| res[attr] = a.person.send(attr.to_s) }
        }
      }
    end

    Rails.logger.debug("[EXPORT] Found #{@metadata.count} attachments")

    unless @metadata.present?
      errors.push('no attachments found')
      return false
    end

    true
  end

  def archive_data
    time_range =
      if @start_time.present? && @end_time.present?
        "#{@start_time.strftime('%Y%m%d%H%M%S')}_#{@end_time.strftime('%Y%m%d%H%M%S')}"
      else
        'all'
      end
    export_time = Time.now.utc.strftime('%Y%m%d%H%M%S')

    tmpdir = File.join(Dir.tmpdir, 'hrms_export')
    FileUtils.mkdir_p(tmpdir)
    zipfile_name = File.join(tmpdir, "hrms_data_#{time_range}_#{export_time}.zip")

    Zip::File.open(zipfile_name, Zip::File::CREATE) do |zipfile| # TODO: handle possible FS errors
      @metadata.each do |file|
        begin
          zipfile.add(file[:id], file[:path])
        rescue
          @errors.push("failed to archive attachment #{file[:path]}")
        end

        file.delete(:path)
      end

      zipfile.get_output_stream('metadata.json') { |file| file.write(@metadata.to_json) }
      zipfile.get_output_stream('metadata_fields_types.json') { |file| file.write(@metadata_fields_types.to_json) }
    end

    @archive_path = zipfile_name
    Rails.logger.info("[EXPORT] Data saved to #{@archive_path}")

    @errors.blank?
  end
end
