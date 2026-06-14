# frozen_string_literal: true

# Configure parameters to be partially matched (e.g. passw matches password) and
# filtered from the log file. Use this to limit dissemination of sensitive info.

Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn,
  :credentials, :api_key, :api_secret, :access_token, :refresh_token
]
