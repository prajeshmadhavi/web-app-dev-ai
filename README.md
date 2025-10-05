The best practices for a web and mobile lab using cloud code involve integrating Firebase Authentication with a self-hosted PostgreSQL database, using Next.js for frontend and backend development, and deploying via platforms like Cloud Run or Firebase App Hosting. Key practices include using server-side rendering in Next.js, securing API keys through Cloud Secret Manager, and implementing continuous deployment from GitHub repositories. For the mobile component, maintain shared authentication through Firebase while connecting to PostgreSQL using environment variables for database credentials, and employ TypeScript with proper type definitions for robust code.[1][2]

### Architecture Design
A recommended architecture uses Firebase Authentication for user management while storing application data in a self-hosted PostgreSQL database, with Next.js serving as the full-stack framework. This setup allows for server-side rendering benefits while maintaining data sovereignty through self-hosted databases. The connection between Next.js and PostgreSQL should use connection pooling with the `pg` library, and authentication tokens from Firebase should be validated on the server before database access. For mobile clients, implement JWT token verification from Firebase Authentication on API endpoints to ensure secure data access.[2][3]

### Development Workflow
Implement a development workflow that leverages GitHub for version control with automated deployments to cloud platforms. Use environment variables to manage configuration differences between development and production environments, particularly for database connection strings and API keys. Structure the Next.js application using the App Router pattern with server components for data fetching and client components for interactive elements. Organize Firebase-specific code in a dedicated library directory to abstract implementation details from components.[1][2]

### GitHub Repositories
Several GitHub repositories provide templates for this architecture: the Firebase Next.js codelab repository offers a complete example of Firebase integration with Next.js using App Router and server-side rendering ; the Mobile-Cloud-Computing-Project repository demonstrates RESTful services for mobile cloud applications ; and various admin panel templates on GitHub can be adapted for PostgreSQL with Firebase Authentication. These repositories showcase proper implementation of environment configuration, database connection management, and secure authentication patterns that can be adapted for your specific use case.[4][5][6][1][2]

[1](https://firebase.google.com/codelabs/firebase-nextjs)
[2](https://codelabs.developers.google.com/codelabs/deploy-application-with-database/cloud-sql-nextjs)
[3](https://www.reddit.com/r/Firebase/comments/lk7luq/how_can_i_use_postgresql_with_firebase_auth/)
[4](https://github.com/topics/cloud-application)
[5](https://github.com/topics/mobile-app)
[6](https://github.com/luispdm/Mobile-Cloud-Computing-Project)
[7](https://firebase.google.com/docs/hosting/frameworks/nextjs)
[8](https://www.reddit.com/r/Firebase/comments/1eh5dgj/i_wrote_a_detailed_guide_for_setting_up_a_nextjs/)
[9](https://blogs.purecode.ai/blogs/nextjs-firebase)
[10](https://codelabs.developers.google.com/codelabs/how-to-deploy-github-cloud-run-using-cloud-build)
[11](https://www.youtube.com/watch?v=qb2Ug9Yoatg)
[12](https://www.youtube.com/watch?v=0icDNqpkEU0&vl=en)
[13](https://www.jetadmin.io/templates/firebase-auth-admin-panel)
[14](https://stackoverflow.com/questions/78158515/cant-read-data-from-a-db-in-a-nextjs-firebase-app)
[15](https://www.jetadmin.io/firebase-admin-panel)
[16](https://stackoverflow.com/questions/37482366/is-it-safe-to-expose-firebase-apikey-to-the-public)
[17](https://uibakery.io/templates/firebase-admin-panel)
[18](https://www.dronahq.com/templates/Postgresql-Admin-Panel/)
[19](https://github.com/features/codespaces)
[20](https://www.appsmith.com/use-case/firebase-admin-panel)
