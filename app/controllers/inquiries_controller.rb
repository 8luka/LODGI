class InquiriesController < ApplicationController
  def clear
    if session[:inquiry_id]
      Inquiry.find_by(id: session[:inquiry_id])&.destroy
      session.delete(:inquiry_id)
    end
    redirect_back(fallback_location: map_path)
  end

  def create
    inquiry = session[:inquiry_id] ? Inquiry.find_by(id: session[:inquiry_id]) : nil
    inquiry ||= Inquiry.new

    inquiry.assign_attributes(
      user: current_user,
      check_in: params[:checkin],
      check_out: params[:checkout],
      guests: params[:guests].presence&.to_i,
      why_visit: params[:trip_type].presence,
      anchor: resolve_anchor(params[:anchor])
    )
    inquiry.save
    session[:inquiry_id] = inquiry.id

    redirect_to map_path
  end

  private

  # The form sends anchor as"shinjuku" so an instance must be found instead
  def resolve_anchor(slug)
    return nil if slug.blank?

    Neighborhood.all.find { |n| n.name.parameterize == slug } ||
      Place.all.find { |p| p.name.parameterize == slug }
  end
end
