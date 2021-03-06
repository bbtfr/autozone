module StatisticsHelper
  def recent resources
    resources.select{|r|r.created_at>1.month.ago}
  end

  def mean_stars reviews
    return 0.0 if reviews.length == 0
    (reviews.map(&:stars).reduce(0.0, :+) / reviews.length).round(2) rescue 0.0
  end

  def total_cost orders
    orders.map(&:cost).reduce(0.0, :+) rescue 0.0
  end

  def ordered_users_count orders
    orders.map(&:user_id).uniq.length
  end

  def goal_attainment orders
    uncanceled_count = orders.length - states_count(orders, :canceled)
    return 0.0 if uncanceled_count == 0
    (states_count(orders, :finished) * 100.0 / uncanceled_count).round(2) rescue 0.0
  end
  
  def states_count orders, state
    state_id = Category::State[state]
    orders.select{|o|o.state_id == state_id}.length
  end

  def print_stars stars, display_text = true
    ret = ""
    iStars = stars.round
    iStars.times { ret << '★' }
    (5 - iStars).times { ret << '☆' }
    ret << " #{stars}" if display_text
    ret.html_safe
  end

end
