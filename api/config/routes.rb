Rage.routes.draw do
  scope path: 'api' do
    get 'portfolios', to: 'portfolios#index'
    post 'portfolios', to: 'portfolios#create'
    get 'portfolios/:id', to: 'portfolios#show'
    patch 'portfolios/:id', to: 'portfolios#update'
    get 'portfolios/:id/snapshots', to: 'portfolios#snapshots'
    post 'portfolios/:id/transactions', to: 'transactions#create'
    delete 'transactions/:id', to: 'transactions#destroy'
    get 'instruments/search', to: 'instruments#search'
    post 'refresh', to: 'refresh#create'
    post 'backfill', to: 'backfill#create'
  end
end
