/*
  Catalog Views
*/
select * from sys.service_message_types
select * from sys.service_contracts
select * from sys.service_contract_message_usages
select * from sys.service_queues
	
/*
  Contract details
*/
SELECT
	 c.name AS 'Contract'
	,mt.name AS 'Message Name'
	,cmu.is_sent_by_initiator
	,cmu.is_sent_by_target
	,mt.validation_desc
FROM
	sys.service_contract_message_usages cmu
JOIN
	sys.service_message_types mt
ON
	mt.message_type_id = cmu.message_type_id
JOIN
	sys.service_contracts c
ON
	c.service_contract_id = cmu.service_contract_id
ORDER BY 1,2

/*
  Names of services and their associated contracts
*/
SELECT
	 s.name as 'Service'
	,c.name as 'Contract'
FROM
	sys.services s
JOIN
	sys.service_contract_usages cu
ON
	cu.service_id = s.service_id
JOIN
	sys.service_contracts c
ON
	c.service_contract_id = cu.service_contract_id
ORDER BY 1,2
