# frozen_string_literal: true

# Backward compatibility layer
# This file provides the CMS class that existing code expects
# It delegates to V7CMS::Application from the gem structure

# Load the gem (which loads all models, helpers, services, and the application)
require_relative '../lib/v7cms'

# Create CMS as an alias to V7CMS::Application for backward compatibility
# This allows existing code using `CMS` or `require 'app/cms'` to continue working
CMS = V7CMS::Application

# Also expose non-namespaced model classes for backward compatibility
# This allows existing code using `Post`, `User`, etc. to continue working
User = V7CMS::User
Post = V7CMS::Post
Page = V7CMS::Page
Comment = V7CMS::Comment
Setting = V7CMS::Setting
Theme = V7CMS::Theme
Redirect = V7CMS::Redirect
Tag = V7CMS::Tag
PostTag = V7CMS::PostTag
Asset = V7CMS::Asset
ContentVersion = V7CMS::ContentVersion
Menu = V7CMS::Menu
MenuItem = V7CMS::MenuItem
Form = V7CMS::Form
FormField = V7CMS::FormField
FormSubmission = V7CMS::FormSubmission

# Expose services for backward compatibility
FeedGenerator = V7CMS::FeedGenerator
GravatarService = V7CMS::GravatarService
HtaccessGenerator = V7CMS::HtaccessGenerator
PageRenderer = V7CMS::PageRenderer
PostRenderer = V7CMS::PostRenderer
ThemeGenerator = V7CMS::ThemeGenerator

# Expose helper for backward compatibility
AuthHelper = V7CMS::AuthHelper
