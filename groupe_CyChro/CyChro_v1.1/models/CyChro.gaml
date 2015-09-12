/**
 *  CyChro 24/06/15
 *  Author: Carlos Delphine Imen Mahé
 *  Description: diffusion d'alerte cyclonique 
 */

model CyChro



global {
	/** Insert the global definitions, variables and actions here */
	// les effectis de chaque espèce d'agent
	int nb_habitant <- 500;
	int nb_sirene <- 30;
	//int nb_sirene_on<-5;
	
	//*******************************
	float speedCyclone<-100.0 #m/#h ;
	int headingCyclone<-10;
	float rangeSiren <- 300#m;
	cyclone katrina;
	const cyclonePicture type: file <- file("../images/Cyclone.gif");
	conecyclone conekatrina;
	point depart<-{161,-130};//point de depart du cyclone
	//*****************************
	float rayoncyclone <- 100#m;

	//*****************************
	//le pas de temps
	float step <- 10 #mn;
	
	//fichiers d'information géographique sous la forme de shapefile
	//file roads_shapefile <- file("../includes/ROUTE.shp");
	//file buildings_shapefile <- file("../includes/bati.shp");
	//file contour_shapefile<- file("../includes/contours_ile.shp");
	
	file roads_shapefile <- file("../includes/routes.shp");
	file buildings_shapefile <- file("../includes/batiments.shp");
	
	//dimensionnement du monde en fonction du territoire
	//geometry shape <- envelope(contour_shapefile);
	geometry shape <- envelope(roads_shapefile);
	
	
	//initialisation d'autres variables
	int nb_danger_init <-0;
	int nb_habitant_not_danger <-0;
	int nb_habitant_danger <- 0;
	graph road_network;
	
	//Pourcentage d'habitants qui a un compte twitter
	float taux_twitter <- 0.1;
	//déclaration d’un réseau social qu’on appelle socialNetwork
	graph<habitant, geometry> socialNetwork; 
	//Seuil a partir duquel un habitant decide de reagir face a un message
	float seuil_action <- 2;
	//Seuil a partir duquel un habitant decide de diffuser un message
	float seuil_diffusion <- 0.5;
	//Rayon dans lequel un habitant va diffuser un message dans le reseau de bouche a oreille
	int rayon_voisinage <- 50 #m;
	//Pourcentage d'habitants qui fait confiance aux messages provenants de leur voisinage
	float taux_confiance_voisinage <- 1;
	//Pourcentage d'habitants qui fait confiance aux messages provenants de Twitter
	float taux_confiance_twitter <- 0;
	//Pourcentage d'habitants qui fait confiance aux messages provenants des sirenes
	float taux_confiance_sirene <- 0;
	
	// indicateurs possibles
	 int nb_dead_init<-0;
	 int nb_dead <- nb_dead_init update: habitant count each.dead;
	 
	int nb_in_my_house_init<-0;
	int nb_in_my_house <- nb_in_my_house_init update: habitant count (each.in_my_house);
	
	int nb_zone_impact_init<-0;
	
	list<habitant> list_habitant_in_cyclone update: list_habitant_in_cyclone + ( habitant inside katrina);
	
	int nb_zone_impact <- nb_zone_impact_init  update: length(remove_duplicates (list_habitant_in_cyclone)) ;

	
	int nb_ping_sirene_init<-0;
	int nb_ping_sirene <- nb_ping_sirene_init update: sirene count each.is_on ;
	
	
	
	//listes des indicateurs a analyser A DEFINIR
	//list<habitant_in_building> list_habitant_in_buildings update: building accumulate each.habitant_in_building;
	//int nb_habitant_danger <- nb_danger_init update: habitant count (each.is_danger) + list_habitant_in_buildings count (each.is_danger);
	//int nb_habitant_not_danger <- nb_habitant - nb_danger_init update: nb_habitant - nb_habitant_danger;
	//float danger_rate update: nb_habitant_danger/nb_habitant;
	
	
	
	// conditions intiales
	init{
		// création données géographiques 
		create road from: roads_shapefile;
		road_network <- as_edge_graph(road);
		create building from: buildings_shapefile;
		//create contour from:contour_shapefile;
		
		//création et localisation des sirènes
		create sirene number:nb_sirene;
		
		
	//*****************************
		
		//création et localisation du cyclone
		create conecyclone {
			location <- point(85.7 ,42.94);
			conekatrina <- self;
		}
		
		create cyclone{
			//location <-first(conekatrina.shape.points);
			location <-conekatrina.shape.points;
			katrina <- self;	
		}
	 
	//*****************************
	
	
			
		
		//création et localisation des habitants
		create habitant number:nb_habitant *(1-taux_twitter){
			my_house <- one_of(building);
			location <- one_of(building);
			}
		
		//initialisation des attributs des habitants
		ask nb_danger_init among habitant {
			is_danger <- false;
			}
		

	//*******************************************
		
		socialNetwork <- generate_watts_strogatz(habitant, relation, nb_habitant * taux_twitter, 0.1, 4.0, true); //utilisation du modèle Small World de WattStrogatz
		
		
		ask habitant
		{
			my_house <- one_of(building);
			location <- one_of(building).location;
			target<- one_of(building).location;
			
		}
		}
		// action de fin de simulation A DEFINIR
	reflex end_simulation when: cycle= 245{
		do pause;
	}	
	
	
}
species relation
{
}

species habitant skills:[moving]{
	/*
	 * target est l'objectif de déplacement
	 * is-danger est false quand l'habitant est chez lui true sinon
	 * is aware est une version simplifiee du vecteur informationnel egal a true si l'agent a recu un message  false sinon
	 * my_house est la maison allouée a chaque habitant pour se refugier
	 * is_my_house ?????????
	 * network1 et network2 sont des versions simplifiees de l'adhesion aux 2 réseaux 
	 * trustInNetwork1 et trustInNetwork2 sont la confiance qu'attribue un habitant a la reception d'un message venant de N1 et de N2
	 * threshold????
	 * in_my_house???? 
	 */
	
	point target;
	bool is_danger <- true;
	bool is_aware<-false;
	building my_house;
	float threshold;
	bool in_my_house <- false;
	
	//(changement de nom) et definition
//	float trustInVoisinage <- ( flip(taux_confiance_voisinage)) ? -rnd(50)/100 :rnd(49)/100;//1:0;//
//	float trustInTwitter <- (flip(taux_confiance_twitter)) ? -rnd(70)/100:rnd(30)/100;//1:0;//
//	float trustInSirene <- (flip( taux_confiance_sirene)) ?-rnd(3)/100:rnd(29)/100; //1:0;//
	float trustInVoisinage <-0.2;
	float trustInTwitter <- 0.2;
	float trustInSirene <- 0.2;
	//Egoisme represente le taux de diffusion qui est indepent des croyances sur les reseaux ou sur les messages
	float egoism <- rnd(10)/10;
	list<string> msg_list;
	list<int> neighbours_list;
	float averageNbNeighbours;
	
	float nbMessBaO;
	float nbMessTw;
	float nbMessSiren;

 
	//Charge informationnelle: contient une valeur qui represente une action par rapport a tous les messages que l'habitant a recu
	float CI;


	//DIAGRAMME UML: Etape 1: "Calcul de la valeur de la charge informationnelle"
	reflex treate_info when: !dead and length(msg_list)>0{
		if((msg_list count (each != "cyclone")) != 0){
			CI <- (trustInVoisinage * (msg_list count (each = "voisinage")) + trustInTwitter * (msg_list count (each = "twitter"))
			+ trustInSirene * (msg_list count (each = "sirene"))); //((msg_list count (each != "cyclone"))* (trustInVoisinage+trustInTwitter+trustInSirene+0.000001));
			
		}else{
			CI<-seuil_action;
		}
//		write(CI);
//		write(msg_list);
		
	}

	//DIAGRAMME UML: Etape 2: "Decision de diffusion" + Etape 3: "Envoyer les messages"
	reflex diffuse when: !dead and egoism <= seuil_diffusion and (CI >= seuil_action)
	{
		int p <- rnd(10)/10;
		if(p<=0.5){
			ask habitant at_distance rayon_voisinage #m
			{
				msg_list << "voisinage";
			}
		}
		write(p);
		p <- rnd(10)/10;
		if(p<=0.5){
			ask (socialNetwork neighbours_of self) {	
				msg_list << "twitter";
			//	write name + " -> " + msg_list;
				
			}
		 
		}
	}
	
	//DIAGRAMME UML: Etape 4: "Se mettre en securite"
	reflex secure when: !dead and CI >= seuil_action
	{
		is_aware <- true;
	}
	
	/****************************** */
	float speed<-0.5 #km/#h;
	bool dead<-false;	
	/****************************** */
		
		reflex move when: ((dead= false) and !(is_aware=true and in_my_house=true)) {
			if (is_aware){
					target <- my_house;		
			}
			else{
				if(in_my_house=false){//sinon je ne suis pas dans ma maison
					//if(rnd(1.0)<0.8){//j'ai une proba de 0.8
					 building bd_target <- one_of(building);//de selectionner un batiment au hasard
					 target <- any_location_in (bd_target);//et ma target est un point dans ce batiment
				//}
				}
				else{//je suis chez moi
					 if(rnd(1.0)<0.5){//j ai une probabilite de 0.01
					 	building bd_target <- one_of(building);//de selectionner un batiment au hasard
					 	target <- any_location_in (bd_target);//et ma target est un point dans ce batiment
					 	//do goto target:target on: road_network;
				}else{
					
					
				}
				
													    
			}
		}
			
			do goto target:target on: road_network;
	}
			

	
	reflex arrive when: !dead{
			if location overlaps my_house {
				averageNbNeighbours<- float(mean(neighbours_list));
				in_my_house<-true;
			}	
	}
	
	
	//l'habitant est représenté par un cercle vert quand il est averti , rouge sinon
	//************ si il meurt c'est une etoile rouge*/
	aspect circle {
	 if !dead{
	 	 draw circle(10) color:!is_aware?  #gold: (in_my_house? #green: #greenyellow);
	 	 	}
	 else{draw square(20) color:#red;	
	 	}
	 	
	}
	
	
	reflex countVoisins {
			neighbours_list <<  length (self neighbours_at (rayon_voisinage ) ) ;
	}
	
		reflex countMessages {
			nbMessBaO <- msg_list count (each = "voisinage") ;
			nbMessTw <- msg_list count (each = "twitter") ;
			nbMessSiren <- msg_list count (each = "sirene");
	}	
}



species sirene {
	/*
	 * is_on true si la sirene est active 
	 */

	bool is_on <-false;
	//*****************************
	//bool zoneselection<-false;
	
	reflex alertesirene when:shape overlaps conekatrina.perception {
		is_on <-!(((0 < cycle) and (cycle <= 36)and (cycle mod 12)) or( (36 <cycle) and (cycle<=72) and (cycle mod 6)) or ((72<cycle) and (cycle<=108) and (cycle mod 3))or ((108<cycle)));
	}
	
	reflex stopsirene when:! (shape overlaps conekatrina.perception) {
		is_on <-false;
	}
	//*****************************
	
	//les sirenes sont représentées par des triangles jaune si les sirenes sont actives noires sinon
	aspect triangle {
		draw triangle(30) color:is_on? #yellow: #black;
	}	
	
	//les sirenes emettent dans un rayon de 200m et modifient le vecteur information de l'habitant
	reflex aware when: is_on{
		ask habitant at_distance rangeSiren #m {
			msg_list <- msg_list + "sirene";	
		}
	}
}


//agent cyclone
species cyclone skills:[moving]{
	
	geometry shape <- circle(200#m);
	
	aspect icon {
		draw cyclonePicture size: 200#m rotate: cycle*10 mod 360;
	}
	
	reflex suiscyclone {
		
	 location <-first(conekatrina.shape.points);
			}	
					
	//reflex evolutionforme {
		//shape <-circle( (cycle<120)? (200+0.1*cycle):200);
//	}
	
	
	reflex awarecyclone{
		ask habitant at_distance rayoncyclone#m {
			if flip(0.5) {
				is_aware <- true;
				speed<-speed*2;
				msg_list <- msg_list + "cyclone";
			}
		}
	}
	
	reflex kill {
		ask habitant inside self{ 
			if !(in_my_house and is_aware){
			averageNbNeighbours<- mean(neighbours_list);
			dead<-true;
			}
		} 
	}
	
	reflex coupure_sirene {
		ask sirene inside self {
				is_on <-false;
		}
	}	
	
	
	
}



species conecyclone skills: [moving]{
	geometry perception; //cone de perception du cyclone
	float perceptionRadius <- 15 min: 10.0; //angle de perception
	float perceptionDistance <- 2000.0;//longueur des cotés du triangle
	//float size <- 2.0; //taille du cyclone (le cercle)	
	path trajectoire;//trajectoire de la tornade
	//point depart; //point de départ du cyclone
	
	init {
		
		location <- depart;//on met le cyclone au depart
		trajectoire<- path ([depart,{740 ,505},{1074 ,610},{1423 ,565},{2044 ,350},{2149,300}]);//creation de la trajectoire comme une ligne passant par plusieurs points
	}
		
	reflex creationTriangle{//creation / mise à jour de la geometrie perception
		point p1 <-{location.x + perceptionDistance * cos(heading + perceptionRadius),location.y + perceptionDistance * sin(heading+perceptionRadius)};
		point p2 <-{location.x + perceptionDistance * cos(heading - perceptionRadius),location.y + perceptionDistance * sin(heading-perceptionRadius)};
		perception <- polygon([location,p1,p2]);//creation du triangle
		//mise à jour de l'angle de perception (a caler finement avec le deplacement du cyclone) 
	//	perceptionRadius <- perceptionRadius - 0.15; 
	}
	
	reflex seDeplace{//permet de déplacer le cyclone sur la trajectoire à une vitesse donnée
		do follow path: trajectoire speed: speedCyclone;
	}
	
	aspect tornadoes{//dessin du cyclone
		if(perception!=nil) {draw perception color:#lightgrey;}
	}	
	
  
  /*  reflex move {
		do move speed: speedCyclone #m/#h heading: headingCyclone;//+rnd(2)+0.3*cycle;
		perceptionRadius <- perceptionRadius - 1.0;
   }*/				
}				

	
//*****************************


// les agents qui correspondent a l'information géographique
species road {
	geometry display_shape <- line(shape.points, 2.0);
	aspect geom {
		draw shape color: #black;
	}
	aspect geom3D {
		draw display_shape color: #black ;
	}
}
species building {
	
	aspect geom{
		draw shape color: #lightgray;
	}
}



//interface utilisateur
experiment new type: gui {
	/** Insert here the definition of the input and output of the model */
		
	parameter 'Number of agents' var: nb_habitant min: 1 max: 5000;
    parameter 'Number of sirens' var: nb_sirene min: 1 max: 50;
    //*****************************
    parameter 'Vitesse initiale du cyclone' var: speedCyclone ;
    parameter 'Direction initiale du cyclone' var: headingCyclone min: 1 max: 360;
    //*****************************
    parameter 'Diametre alerte des sirenes' var: rangeSiren min: 1 ;
    
    parameter 'Rayon de Voisinage du cyclone' var: rayoncyclone min: 1 ;

	
	output {
		//monitor "Infected people rate" value: infected_rate;
		
		display map {
			species road aspect:geom;
			species building aspect:geom;
			
			species habitant aspect:circle;
			species sirene aspect:triangle;
			
			//*****************************
			species cyclone aspect:icon  transparency: 0.5;
			species conecyclone aspect:tornadoes  transparency: 0.5;
		
			//species tornadoes aspect:cyclone;
			graphics "trajectoire" {
				draw first(conecyclone).trajectoire.shape color: #red ;	
			}
		}
		
		display chart_display refresh_every: 10 {
			chart "Alerte spreading" type: series {
				data "dead" value: nb_dead color: #purple;
				data "in_house" value: nb_in_my_house color: #blue;
				data "sous le cyclone" value: nb_zone_impact color: #brown;
				}
		}
		display chart_display2 refresh_every: 10 {
			chart "fonctionnement des alertes" type: series {
				data "nombre d'alerte diffusée par sirene" value: nb_ping_sirene color: #yellow;
				}
		}
		//*****************************
		
//		display map refresh_every: 1
//		{
//			graphics "socnet"
//			{
//				loop edge over: socialNetwork.edges
//				{
//					draw edge color: rgb("blue");
//				}
//
//			}
//
//		}
	}	
}
