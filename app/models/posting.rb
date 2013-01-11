class Posting < ActiveRecord::Base
  attr_accessible :title, :company, :description, :comments, :jobtype, :contact, :active_until, :state, :url, :location, :rich_description, :tags, :attachment
  has_attached_file :attachment
  has_and_belongs_to_many :tags
  belongs_to :employer
  belongs_to :student
  belongs_to :reviewer, :foreign_key => 'reviewed_by', :class_name => "Student"

  after_create :alert_admins_of_new_posting

  def active?
    active_until <= DateTime.now
  end

  def visible?
    (active_until <= DateTime.now) && (state == Posting.state_symbol_to_id(:approved))
  end

  def self.all_internships
    Posting.where(:jobtype => jobtype_symbol_to_id(:internship))
  end

  def self.all_parttime
    Posting.where(:jobtype => jobtype_symbol_to_id(:parttime))
  end

  def self.all_fulltime
    Posting.where(:jobtype => jobtype_symbol_to_id(:fulltime))
  end

  def self.all_approved_internships
    Posting.where(:jobtype => jobtype_symbol_to_id(:internship), :state => state_symbol_to_id(:approved))
  end

  def self.all_approved_parttime
    Posting.where(:jobtype => jobtype_symbol_to_id(:parttime), :state => state_symbol_to_id(:approved))
  end

  def self.all_approved_fulltime
    Posting.where(:jobtype => jobtype_symbol_to_id(:fulltime), :state => state_symbol_to_id(:approved))
  end

  # Override the state setter to take a symbol
  def state=(value)
    type = Posting.state_symbol_to_id(value)
    if not type.nil?
      write_attribute(:state, type)
      save
      if value == :pending && !reviewer.nil?
        Student.admins.each do |admin|
          if (admin.alert_on_updated_posting || (posting.reviewer == admin && admin.alert_on_my_updated_posting)) && !admin.digests
            Notifier.admin_updated_posting_notification(self, admin).deliver
          end
        end
      elsif value == :approved
        Notifier.employer_posting_status_change(self).deliver
        Student.all.each do |student|
          if student.alert_on_new_recommendation && student.is_interested_in?(self)
            Notifier.student_job_alert(self, student).deliver
          end
        end
      else
        Notifier.employer_posting_status_change(self).deliver unless value == :pending
      end
      return true
    else
      return false
    end
  end

  # Override the tags setter to parse a string (needed for proper CanCan parsing and just to simplify code elsewhere)
  def tags=(value)
    taglist = value.split(";")
    taglist.each do |tag|
      tags << Tag.find_or_create_by_name(tag)
    end
  end

  def state_as_string
    case Posting.state_id_to_symbol(state)
      when :rejected then "Rejected"
      when :pending then "Pending"
      when :changes_needed then "Changes Needed"
      when :approved then "Approved"
    end
  end

  def job_type_as_symbol
    Posting.jobtype_id_to_symbol(jobtype)
  end

  def self.postings_pending_approval?
    Posting.where(:state => state_symbol_to_id(:pending)).count > 0
  end

  def self.postings_pending_approval
    Posting.where(:state => state_symbol_to_id(:pending))
  end

  def owned_by?(c_student, c_employer)
    (c_student && c_student.is_admin?) || (c_employer && self.employer == c_employer)
  end

  def has_comments?
    !self.comments.nil? && !self.comments.empty?
  end

  def approved?
    Posting.state_id_to_symbol(state) == :approved
  end

  def rejected?
    Posting.state_id_to_symbol(state) == :rejected
  end

  def changes_needed?
    Posting.state_id_to_symbol(state) == :changes_needed
  end

  def pending?
    Posting.state_id_to_symbol(state) == :pending
  end

  private

  def self.jobtype_symbol_to_id(_jobtype)
    case _jobtype
      when :internship then 0
      when :parttime then 1
      when :fulltime then 2
    end
  end

  def self.jobtype_id_to_symbol(_jobtype)
    case _jobtype
      when 0 then :internship
      when 1 then :parttime
      when 2 then :fulltime
    end
  end

  def self.state_id_to_symbol(_state)
    case _state
      when 0 then :rejected
      when 1 then :pending
      when 2 then :changes_needed
      when 3 then :approved
    end
  end

  def self.state_symbol_to_id(_state)
    case _state
      when :rejected then 0
      when :pending then 1
      when :changes_needed then 2
      when :approved then 3
    end
  end

  def alert_admins_of_new_posting
    Student.admins.each do |admin|
      if admin.alert_on_new_posting && !admin.digests
        Notifier.admin_new_posting_notification(self, admin).deliver
      end
    end
  end
end
