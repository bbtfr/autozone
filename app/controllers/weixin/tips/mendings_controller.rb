class Weixin::Tips::MendingsController < Weixin::ApplicationController
  set_resource_class ::Tips::Mending, singleton: true

end