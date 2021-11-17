deploy-common:
	DEPLOY_ENVIRONMENT=common runway deploy
destroy-common:
	DEPLOY_ENVIRONMENT=common runway destroy
deploy-vpc:
		DEPLOY_ENVIRONMENT=common runway deploy --tag vpc
deploy-img-mgr:
		DEPLOY_ENVIRONMENT=dev runway deploy --tag img-mgr
