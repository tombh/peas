require 'spec_helper'

describe App do
  let(:app) { Fabricate :app }

  it 'should get and set the @job instance variable' do
    app.job = '123'
    expect(app.job).to eq '123'
  end

  

end
