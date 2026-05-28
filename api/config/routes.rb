Rage.routes.draw do
  scope path: 'api' do
    get 'portfolios', to: 'portfolios#index'
    post 'portfolios', to: 'portfolios#create'
    get 'portfolios/:id', to: 'portfolios#show'
    patch 'portfolios/:id', to: 'portfolios#update'
    get 'portfolios/:id/snapshots', to: 'portfolio_snapshots#index'
    post 'portfolios/:id/transactions', to: 'transactions#create'
    post 'portfolios/:id/import', to: 'imports#create'
    delete 'transactions/:id', to: 'transactions#destroy'
    get 'snapshots', to: 'snapshots#index'
    get 'schedule', to: 'schedule#index'
    get 'settings', to: 'settings#show'
    patch 'settings', to: 'settings#update'
    get 'instruments', to: 'instruments#index'
    post 'refresh', to: 'refresh#create'
    post 'backfill', to: 'backfill#create'
    post 'internal/refreshed', to: 'internal#refreshed'
  end
end
