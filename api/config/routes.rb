Rage.routes.draw do
  scope path: 'api' do
    get 'portfolios', to: 'portfolios#index'
    post 'portfolios', to: 'portfolios#create'
    get 'portfolios/:id', to: 'portfolios#show'
    patch 'portfolios/:id', to: 'portfolios#update'
    get 'portfolios/:id/snapshots', to: 'portfolio_snapshots#index'
    post 'portfolios/:id/transactions', to: 'transactions#create'
    delete 'transactions/:id', to: 'transactions#destroy'
    get 'snapshots', to: 'snapshots#index'
    get 'instruments', to: 'instruments#index'
    post 'refresh', to: 'refresh#create'
    post 'backfill', to: 'backfill#create'
  end
end
