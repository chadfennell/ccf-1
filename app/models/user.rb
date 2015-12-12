class User < ActiveRecord::Base
  attr_accessible :admin, :department, :deptid, :email, :name, :uid, :image, :verified, :send_notifications

  has_many :projects, :foreign_key => :project_owner_id
  has_many :project_comments
  has_many :commented_projects, through: :project_comments, source: :project
  has_many :project_ratings
  has_many :project_volunteers
  has_many :event_registrations
  has_many :organization_users
  has_many :invitations
  has_many :provider_users, dependent: :destroy

  default_scope { order(:created_at)}
  scope :project_notifiable, ->(id){ joins("INNER JOIN project_comments AS pc ON pc.user_id = users.id INNER JOIN projects AS p ON p.id = pc.project_id").where("p.id = ?", id).where(send_notifications: true ) }


  # See: https://github.com/zquestz/omniauth-google-oauth2 
  def self.create_with_omniauth(auth, organization=nil)
    email = auth.info.email || "#{auth.uid}@#{auth.provider}"
    
    if User.where(email: email).exists?
      user = User.where(email: email).first
    else
      user = create! do |new_user|
        new_user.uid = auth.uid
        new_user.name = auth.info.name
        new_user.email = email
        new_user.image = auth.info.image
        new_user.verified = false

        # First user to sign up becomes an admin... so... sign up fast.
        new_user.admin = 1 if User.count < 1
      end
    end

    user.provider_users.create(provider: auth.provider, uid: auth.uid, validated: true)
    organization.users.where(user: user).first_or_create if organization
    user
  end

  def label
    if !self.department.nil? and !self.department.empty? then
      self.name + ' - ' + self.department
    else
      self.name
    end
  end

  def deactivate
    if self.update_attributes(uid: nil, name: "Deactivated Account", email: "None", image: nil, admin: false, verified: false)
      organization_users.update_all(admin: false, verified: false)
      return true
    else
      return false
    end
  end

  def pending_invitations
    Invitation.pending.user(self)
  end
end
