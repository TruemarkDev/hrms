class Person < ActiveRecord::Base
  acts_as_taggable_on :tags
  attachment :photo

  PRIMARY_TECHS = %w(
    Ruby
    Frontend
    Fullstack
    NET
    Java
    iOS
    Android
    Salesforce
    DevOps
    PM
    QA/BA
    C/C++/Go
    DBA
    HR
    Manager
    PHP
    Scala
    UI/UX
  )
  ENGLISH_LEVELS = %w(
    Beginner/Elementary
    Pre-Intermediate
    Intermediate
    Upper-Intermediate
    Advanced
  )
  EMPLOYEE_STATUSES = ['Hired', 'Past employee', 'Contractor', 'Past contractor']
  SOURCES = %w(Reference Djinni LinkedIn DOU)
  SALARY_TYPES = %w(Monthly Hourly)

  belongs_to :updated_by, class_name: 'User'
  has_many :action_points
  has_many :attachments
  has_many :dayoffs
  has_many :notes

  before_validation :cleanup
  before_save :strip_values

  validates :name, presence: true
  validates :source, inclusion: { in: SOURCES }, allow_blank: true
  validates :salary_type, inclusion: { in: SALARY_TYPES }, allow_blank: true
  validates :primary_tech, inclusion: { in: PRIMARY_TECHS }
  validates :vacation_override, numericality: { only_integer: true}, allow_blank: true
  validates :email, :phone, :skype, :linkedin, uniqueness: { case_sensitive: false }, allow_blank: true
  validates :phone, format: { with: /\A[\s\+\d]+\z/ }, allow_blank: true
  validates :email, format: { with: /\A[a-z\@\.\-\'\+]+\z/ }, allow_blank: true

  scope :not_deleted, ->() { where(is_deleted: false) }
  scope :employee, ->() { where(status: EMPLOYEE_STATUSES).order(:status) }
  scope :current_employee, ->() { where(status: 'Hired').order(:name) }

  def linkedin_value
    if self.linkedin.start_with?('https://')
      self.linkedin
    elsif self.linkedin.start_with?('http://')
      self.linkedin.gsub('http://', 'https://')
    else
      "https://#{self.linkedin}"
    end
  end

private

  def cleanup
    self.email = email.to_s.downcase
  end

  def strip_values
    self.phone = self.phone.strip
    self.current_position = self.current_position.strip
    self.email = self.email.strip
    self.skype = self.skype.strip
    self.linkedin = self.linkedin.strip
    self.name = self.name.strip
  end
end
