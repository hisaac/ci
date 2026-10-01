BEGIN IMMEDIATE;
INSERT OR REPLACE INTO access (
	service, client, client_type, auth_value, auth_reason, auth_version,
	indirect_object_identifier_type, indirect_object_identifier
) VALUES (
	'kTCCServiceAccessibility', '/usr/libexec/sshd-keygen-wrapper', 1, 2, 0, 1,
	NULL, 'UNUSED'
);
COMMIT;
